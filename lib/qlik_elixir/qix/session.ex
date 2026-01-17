defmodule QlikElixir.QIX.Session do
  @moduledoc """
  WebSocket session management for Qlik Engine API (QIX).

  Provides GenServer-based connection management for real-time communication
  with Qlik Engine via JSON-RPC over WebSocket.

  ## Usage

      # Connect to an app
      {:ok, session} = QlikElixir.QIX.Session.connect("app-id", config: config)

      # Make requests
      {:ok, result} = QlikElixir.QIX.Session.request(session, "Doc.GetAllSheets", app_handle, [])

      # Disconnect
      :ok = QlikElixir.QIX.Session.disconnect(session)

  ## Architecture

  Each session is a GenServer that:
  - Maintains a gun WebSocket connection
  - Correlates requests with responses via JSON-RPC IDs
  - Manages object handles for the connected app

  """

  use GenServer, restart: :temporary

  alias QlikElixir.{Config, Error}
  alias QlikElixir.QIX.Protocol

  @default_timeout 30_000
  @connect_timeout 10_000

  defstruct [
    :config,
    :app_id,
    :conn_pid,
    :stream_ref,
    :app_handle,
    request_id: 1,
    pending_requests: %{},
    handles: %{}
  ]

  @type t :: %__MODULE__{
          config: Config.t(),
          app_id: String.t(),
          conn_pid: pid() | nil,
          stream_ref: reference() | nil,
          app_handle: non_neg_integer() | nil,
          request_id: pos_integer(),
          pending_requests: map(),
          handles: map()
        }

  # Public API

  @doc """
  Connects to a Qlik app via WebSocket.

  ## Options

    * `:config` - Required. QlikElixir.Config struct with tenant_url and api_key.
    * `:timeout` - Connection timeout in ms (default: 10000).

  ## Returns

    * `{:ok, pid}` - Session process PID
    * `{:error, Error.t()}` - Connection failed

  """
  @spec connect(String.t() | nil, keyword()) :: {:ok, pid()} | {:error, Error.t()}
  def connect(app_id, opts \\ [])

  def connect(nil, _opts) do
    {:error, Error.validation_error("app_id is required")}
  end

  def connect("", _opts) do
    {:error, Error.validation_error("app_id is required")}
  end

  def connect(app_id, opts) when is_binary(app_id) do
    case get_config(opts) do
      {:ok, config} ->
        GenServer.start_link(__MODULE__, {app_id, config, opts})

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Makes a JSON-RPC request to the Qlik Engine.

  ## Parameters

    * `session` - Session PID
    * `method` - Method name (e.g., "Doc.GetAllSheets")
    * `handle` - Object handle (0 for Global, app_handle for Doc methods)
    * `params` - Method parameters as a list

  ## Options

    * `:timeout` - Request timeout in ms (default: 30000)

  """
  @spec request(pid(), String.t(), non_neg_integer(), list(), keyword()) ::
          {:ok, any()} | {:error, Error.t()}
  def request(session, method, handle, params, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    try do
      GenServer.call(session, {:request, method, handle, params}, timeout)
    catch
      :exit, {:noproc, _} ->
        {:error, Error.network_error("Session not running")}

      :exit, {:timeout, _} ->
        {:error, Error.network_error("Request timed out")}
    end
  end

  @doc """
  Disconnects the session.
  """
  @spec disconnect(pid()) :: :ok
  def disconnect(session) do
    if is_pid(session) and Process.alive?(session) do
      GenServer.stop(session, :normal)
    end

    :ok
  catch
    :exit, _ -> :ok
  end

  @doc """
  Gets the app handle for the connected session.
  """
  @spec get_app_handle(pid()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def get_app_handle(session) do
    GenServer.call(session, :get_app_handle)
  catch
    :exit, _ -> {:error, Error.network_error("Session not running")}
  end

  @doc """
  Builds the WebSocket URL for connecting to an app.
  """
  @spec build_websocket_url(String.t(), Config.t()) :: String.t()
  def build_websocket_url(app_id, config) do
    tenant_url = String.trim_trailing(config.tenant_url, "/")
    ws_scheme = if String.starts_with?(tenant_url, "https://"), do: "wss", else: "ws"
    base_url = String.replace(tenant_url, ~r{^https?://}, "")

    "#{ws_scheme}://#{base_url}/app/#{app_id}"
  end

  @doc """
  Parses a WebSocket URL into components for gun.
  """
  @spec parse_websocket_url(String.t()) :: {:ok, charlist(), non_neg_integer(), String.t()} | {:error, any()}
  def parse_websocket_url(url) do
    case URI.parse(url) do
      %URI{host: nil} ->
        {:error, :invalid_url}

      %URI{host: host, port: port, path: path, scheme: scheme} ->
        actual_port =
          port || if(scheme == "wss", do: 443, else: 80)

        {:ok, to_charlist(host), actual_port, path || "/"}
    end
  end

  # GenServer Callbacks

  @impl true
  def init({app_id, config, opts}) do
    state = %__MODULE__{
      config: config,
      app_id: app_id
    }

    case establish_connection(state, opts) do
      {:ok, new_state} ->
        {:ok, new_state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:request, method, handle, params}, from, state) do
    {:ok, json, request_id} = Protocol.encode_request(method, handle, params, state.request_id)

    case :gun.ws_send(state.conn_pid, state.stream_ref, {:text, json}) do
      :ok ->
        new_pending = Map.put(state.pending_requests, request_id, from)
        new_state = %{state | request_id: request_id + 1, pending_requests: new_pending}
        {:noreply, new_state}

      {:error, reason} ->
        {:reply, {:error, Error.network_error("Failed to send request: #{inspect(reason)}")}, state}
    end
  end

  @impl true
  def handle_call(:get_app_handle, _from, state) do
    case state.app_handle do
      nil -> {:reply, {:error, Error.network_error("App not opened")}, state}
      handle -> {:reply, {:ok, handle}, state}
    end
  end

  @impl true
  def handle_info({:gun_ws, _conn_pid, _stream_ref, {:text, data}}, state) do
    case Protocol.decode_response(data) do
      {:ok, %{id: id, result: result}} ->
        handle_response(state, id, {:ok, result})

      {:error, %{id: id} = error_info} ->
        error = Error.network_error("QIX error: #{error_info.message}", details: error_info)
        handle_response(state, id, {:error, error})

      {:error, reason} ->
        require Logger
        Logger.warning("Invalid QIX response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:gun_ws, _conn_pid, _stream_ref, :close}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:gun_down, _conn_pid, _protocol, _reason, _killed_streams}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.conn_pid do
      :gun.close(state.conn_pid)
    end

    :ok
  end

  # Private Functions

  defp get_config(opts) do
    case Keyword.get(opts, :config) do
      %Config{} = config -> {:ok, config}
      nil -> {:error, Error.configuration_error("Config is required for QIX session")}
    end
  end

  defp establish_connection(state, opts) do
    url = build_websocket_url(state.app_id, state.config)
    timeout = Keyword.get(opts, :timeout, @connect_timeout)

    with {:ok, host, port, path} <- parse_websocket_url(url),
         {:ok, conn_pid} <- open_connection(host, port, timeout),
         {:ok, stream_ref} <- upgrade_to_websocket(conn_pid, host, path, state.config, timeout),
         {:ok, app_handle} <- open_app(conn_pid, stream_ref, state.app_id, timeout) do
      {:ok, %{state | conn_pid: conn_pid, stream_ref: stream_ref, app_handle: app_handle}}
    else
      {:error, reason} ->
        {:error, Error.network_error("Connection failed: #{inspect(reason)}")}
    end
  end

  defp open_connection(host, port, timeout) do
    transport = if port == 443, do: :tls, else: :tcp

    tls_opts =
      if transport == :tls do
        [verify: :verify_peer, cacerts: :public_key.cacerts_get()]
      else
        []
      end

    gun_opts = %{
      connect_timeout: timeout,
      transport: transport,
      tls_opts: tls_opts,
      # Force HTTP/1.1 - WebSocket upgrades don't work over HTTP/2
      protocols: [:http]
    }

    case :gun.open(host, port, gun_opts) do
      {:ok, conn_pid} ->
        case :gun.await_up(conn_pid, timeout) do
          {:ok, _protocol} -> {:ok, conn_pid}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upgrade_to_websocket(conn_pid, host, path, config, timeout) do
    origin = String.trim_trailing(config.tenant_url, "/")

    headers = [
      {~c"authorization", ~c"Bearer #{config.api_key}"},
      {~c"host", host},
      {~c"origin", String.to_charlist(origin)}
    ]

    stream_ref = :gun.ws_upgrade(conn_pid, path, headers)

    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], _headers} ->
        {:ok, stream_ref}

      {:gun_response, ^conn_pid, ^stream_ref, _fin, status, _headers} ->
        {:error, {:http_error, status}}

      {:gun_error, ^conn_pid, ^stream_ref, reason} ->
        {:error, reason}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp open_app(conn_pid, stream_ref, app_id, timeout) do
    params = Protocol.build_open_doc(app_id)
    # Global handle is -1 in QIX API
    {:ok, json, request_id} = Protocol.encode_request("OpenDoc", -1, params, 1)

    case :gun.ws_send(conn_pid, stream_ref, {:text, json}) do
      :ok ->
        wait_for_response(conn_pid, stream_ref, request_id, timeout)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_response(conn_pid, stream_ref, expected_id, timeout) do
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} ->
        case Protocol.decode_response(data) do
          {:ok, %{id: ^expected_id, result: result}} ->
            Protocol.extract_handle(result)

          {:error, %{id: ^expected_id, message: message}} ->
            {:error, message}

          _ ->
            wait_for_response(conn_pid, stream_ref, expected_id, timeout)
        end

      {:gun_ws, ^conn_pid, ^stream_ref, :close} ->
        {:error, :connection_closed}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp handle_response(state, id, result) do
    case Map.pop(state.pending_requests, id) do
      {nil, _} ->
        {:noreply, state}

      {from, new_pending} ->
        GenServer.reply(from, result)
        {:noreply, %{state | pending_requests: new_pending}}
    end
  end
end
