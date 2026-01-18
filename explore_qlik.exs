# Comprehensive Qlik Cloud Exploration Script
#
# Setup:
#   1. Copy .env.example to .env
#   2. Fill in your Qlik Cloud credentials and IDs
#   3. Run: export $(grep -v '^#' .env | sed 's/"//g' | xargs) && mix run explore_qlik.exs
#
# Required environment variables:
#   QLIK_API_KEY      - Your Qlik Cloud API key
#   QLIK_BASE_URL     - Your tenant URL (e.g., https://tenant.region.qlikcloud.com)
#   QLIK_TARGET_APP_ID   - App ID to explore
#   QLIK_TARGET_SPACE_ID - Space ID to explore
#
# Optional:
#   QLIK_TEST_FILENAME - Filename to search for (default: test.qvd)

alias QlikElixir.{Config, Error}
alias QlikElixir.REST.{Apps, Spaces, Reloads, DataFiles, Users, APIKeys, Automations, Webhooks, DataConnections}
alias QlikElixir.REST.{Tenants, Groups, Roles, Audits}
alias QlikElixir.REST.{Items, Collections, Reports, NaturalLanguage}

# Configuration - all from environment variables
api_key = System.get_env("QLIK_API_KEY") || raise "QLIK_API_KEY not set"
base_url = System.get_env("QLIK_BASE_URL") || raise "QLIK_BASE_URL not set"

# Target app and space from environment
target_app_id = System.get_env("QLIK_TARGET_APP_ID") || raise "QLIK_TARGET_APP_ID not set"
target_space_id = System.get_env("QLIK_TARGET_SPACE_ID") || raise "QLIK_TARGET_SPACE_ID not set"
test_filename = System.get_env("QLIK_TEST_FILENAME") || "test.qvd"

config = Config.new(api_key: api_key, tenant_url: base_url)

defmodule Explorer do
  def header(title) do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts(title)
    IO.puts(String.duplicate("=", 70))
  end

  def subheader(title) do
    IO.puts("\n--- #{title} ---")
  end

  def success(msg), do: IO.puts("[OK] #{msg}")
  def info(msg), do: IO.puts("     #{msg}")
  def error(msg), do: IO.puts("[ERROR] #{msg}")
end

Explorer.header("QLIK CLOUD COMPREHENSIVE EXPLORATION")
IO.puts("Tenant: #{base_url}")
IO.puts("Target App ID: #{target_app_id}")
IO.puts("Target Space ID: #{target_space_id}")

# =============================================================================
# SECTION 1: APPS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 1: APPS API")

# 1.1 List all apps with pagination
Explorer.subheader("1.1 List All Apps (paginated)")
all_apps = []
cursor = nil
page = 1

all_apps =
  Stream.unfold({nil, 1}, fn
    {:done, _} -> nil
    {cursor, page} ->
      opts = [config: config, limit: 20] ++ if(cursor, do: [next: cursor], else: [])
      case Apps.list(opts) do
        {:ok, %{"data" => apps, "links" => links}} ->
          next_cursor = if links["next"], do: links["next"]["href"] |> URI.parse() |> Map.get(:query) |> URI.decode_query() |> Map.get("next")
          IO.puts("  Page #{page}: #{length(apps)} apps")
          if next_cursor && page < 10 do  # Limit to 10 pages
            {apps, {next_cursor, page + 1}}
          else
            {apps, {:done, page}}
          end
        {:ok, %{"data" => apps}} ->
          IO.puts("  Page #{page}: #{length(apps)} apps (last page)")
          {apps, {:done, page}}
        {:error, err} ->
          Explorer.error("Failed: #{inspect(err)}")
          {[], {:done, page}}
      end
  end)
  |> Enum.to_list()
  |> List.flatten()

Explorer.success("Total apps found: #{length(all_apps)}")

# 1.2 Filter apps by space
Explorer.subheader("1.2 Apps in Target Space")
case Apps.list(config: config, space_id: target_space_id) do
  {:ok, %{"data" => apps}} ->
    Explorer.success("Found #{length(apps)} apps in target space:")
    Enum.each(apps, fn app ->
      attrs = app["attributes"]
      Explorer.info("#{attrs["name"]} - Last reload: #{attrs["lastReloadTime"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 1.3 Get detailed info for target app
Explorer.subheader("1.3 Target App Details")
case Apps.get(target_app_id, config: config) do
  {:ok, app} ->
    attrs = app["attributes"]
    Explorer.success("App: #{attrs["name"]}")
    Explorer.info("ID: #{attrs["id"]}")
    Explorer.info("Description: #{attrs["description"] || "(none)"}")
    Explorer.info("Owner ID: #{attrs["ownerId"]}")
    Explorer.info("Owner: #{attrs["owner"]}")
    Explorer.info("Space ID: #{attrs["spaceId"]}")
    Explorer.info("Published: #{attrs["published"]}")
    Explorer.info("Created: #{attrs["createdDate"]}")
    Explorer.info("Modified: #{attrs["modifiedDate"]}")
    Explorer.info("Last Reload: #{attrs["lastReloadTime"]}")
    Explorer.info("Publish Time: #{attrs["publishTime"]}")
    Explorer.info("Dynamic Color: #{attrs["dynamicColor"]}")
    Explorer.info("Thumbnail: #{if attrs["thumbnail"], do: "yes", else: "no"}")
    Explorer.info("Has Section Access: #{attrs["hasSectionAccess"]}")
    Explorer.info("Encrypted: #{attrs["encrypted"]}")
    Explorer.info("Origin App ID: #{attrs["originAppId"]}")
    Explorer.info("Is Direct Query: #{attrs["isDirectQueryMode"]}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 1.4 Get app metadata
Explorer.subheader("1.4 App Metadata (Data Model Info)")
case Apps.get_metadata(target_app_id, config: config) do
  {:ok, metadata} ->
    Explorer.success("Metadata retrieved:")
    Enum.each(metadata, fn {k, v} ->
      Explorer.info("#{k}: #{inspect(v)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 1.5 Get data lineage
Explorer.subheader("1.5 Data Lineage (Data Sources)")
case Apps.get_lineage(target_app_id, config: config) do
  {:ok, lineage} when is_list(lineage) ->
    Explorer.success("Found #{length(lineage)} lineage entries")

    # Group by discriminator
    by_type = Enum.group_by(lineage, & &1["discriminator"])
    Enum.each(by_type, fn {type, entries} ->
      Explorer.info("#{type}: #{length(entries)} entries")
    end)

    # Show sample statements
    IO.puts("\n  Sample data sources:")
    lineage
    |> Enum.filter(& &1["statement"])
    |> Enum.take(5)
    |> Enum.each(fn entry ->
      stmt = entry["statement"] |> String.split("\n") |> List.first() |> String.slice(0, 80)
      Explorer.info("[#{entry["discriminator"]}] #{stmt}...")
    end)
  {:ok, lineage} ->
    Explorer.success("Lineage: #{inspect(lineage)}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 1.6 Search apps by name
Explorer.subheader("1.6 Search Apps by Name")
search_terms = ["Sales", "Dashboard", "ETL", "Report"]
Enum.each(search_terms, fn term ->
  case Apps.list(config: config, name: term) do
    {:ok, %{"data" => apps}} ->
      Explorer.info("'#{term}': #{length(apps)} matches")
    {:error, _} ->
      Explorer.info("'#{term}': search failed")
  end
end)

# =============================================================================
# SECTION 2: SPACES API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 2: SPACES API")

# 2.1 List all spaces
Explorer.subheader("2.1 All Spaces")
case Spaces.list(config: config, limit: 100) do
  {:ok, %{"data" => spaces}} ->
    Explorer.success("Found #{length(spaces)} spaces")

    # Group by type
    by_type = Enum.group_by(spaces, & &1["type"])
    Enum.each(by_type, fn {type, list} ->
      IO.puts("\n  #{String.upcase(type)} spaces (#{length(list)}):")
      Enum.each(list, fn space ->
        Explorer.info("#{space["name"]} (#{space["id"]})")
      end)
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 2.2 Filter by type
Explorer.subheader("2.2 Filter Spaces by Type")
["shared", "managed", "data"] |> Enum.each(fn type ->
  case Spaces.list(config: config, type: type) do
    {:ok, %{"data" => spaces}} ->
      Explorer.info("#{type}: #{length(spaces)} spaces")
    {:error, _} ->
      Explorer.info("#{type}: query failed")
  end
end)

# 2.3 Get target space details
Explorer.subheader("2.3 Target Space Details")
case Spaces.get(target_space_id, config: config) do
  {:ok, space} ->
    Explorer.success("Space: #{space["name"]}")
    Explorer.info("ID: #{space["id"]}")
    Explorer.info("Type: #{space["type"]}")
    Explorer.info("Description: #{space["description"] || "(none)"}")
    Explorer.info("Owner ID: #{space["ownerId"]}")
    Explorer.info("Tenant ID: #{space["tenantId"]}")
    Explorer.info("Created: #{space["createdAt"]}")
    Explorer.info("Updated: #{space["updatedAt"]}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 2.4 List space assignments (who has access)
Explorer.subheader("2.4 Target Space Assignments")
case Spaces.list_assignments(target_space_id, config: config) do
  {:ok, %{"data" => assignments}} ->
    Explorer.success("Found #{length(assignments)} assignments")
    Enum.each(assignments, fn a ->
      roles = (a["roles"] || []) |> Enum.join(", ")
      Explorer.info("#{a["type"]}: #{a["assigneeId"]} - Roles: [#{roles}]")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 2.5 Space types
Explorer.subheader("2.5 Available Space Types")
case Spaces.list_types(config: config) do
  {:ok, types} ->
    Explorer.success("Space types:")
    cond do
      is_list(types) ->
        Enum.each(types, fn t ->
          if is_map(t), do: Explorer.info("#{t["name"]}: #{inspect(t["actions"])}")
        end)
      is_map(types) && types["data"] ->
        Enum.each(types["data"], fn t ->
          if is_map(t), do: Explorer.info("#{t["name"]}: #{inspect(t["actions"])}")
        end)
      true ->
        Explorer.info(inspect(types))
    end
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 3: RELOADS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 3: RELOADS API")

# 3.1 Recent reloads across all apps
Explorer.subheader("3.1 Recent Reloads (All Apps)")
case Reloads.list(config: config, limit: 20) do
  {:ok, %{"data" => reloads}} ->
    Explorer.success("Found #{length(reloads)} recent reloads")

    # Group by status
    by_status = Enum.group_by(reloads, & &1["status"])
    Enum.each(by_status, fn {status, list} ->
      Explorer.info("#{status}: #{length(list)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 3.2 Filter by status
Explorer.subheader("3.2 Reloads by Status")
["QUEUED", "RELOADING", "SUCCEEDED", "FAILED", "CANCELED"] |> Enum.each(fn status ->
  case Reloads.list(config: config, status: status, limit: 5) do
    {:ok, %{"data" => reloads}} ->
      Explorer.info("#{status}: #{length(reloads)} found")
    {:error, _} ->
      Explorer.info("#{status}: query failed")
  end
end)

# 3.3 Reloads for target app
Explorer.subheader("3.3 Target App Reload History")
case Reloads.list(config: config, app_id: target_app_id, limit: 10) do
  {:ok, %{"data" => reloads}} ->
    Explorer.success("Found #{length(reloads)} reloads for target app")
    Enum.each(reloads, fn r ->
      duration = r["duration"] || "N/A"
      Explorer.info("#{r["status"]} | #{r["endTime"] || r["creationTime"]} | Duration: #{duration}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 3.4 Get specific reload details
Explorer.subheader("3.4 Latest Reload Details")
case Reloads.list(config: config, app_id: target_app_id, limit: 1) do
  {:ok, %{"data" => [latest | _]}} ->
    case Reloads.get(latest["id"], config: config) do
      {:ok, reload} ->
        Explorer.success("Reload: #{reload["id"]}")
        Enum.each(reload, fn {k, v} ->
          Explorer.info("#{k}: #{inspect(v)}")
        end)
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No reloads found")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 4: DATA FILES API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 4: DATA FILES API")

# 4.1 List all data files
Explorer.subheader("4.1 All Data Files")
case DataFiles.list(config: config, limit: 50) do
  {:ok, %{"data" => files}} ->
    Explorer.success("Found #{length(files)} data files")

    total_size = Enum.reduce(files, 0, fn f, acc -> acc + (f["size"] || 0) end)
    Explorer.info("Total size: #{Float.round(total_size / 1024, 2)} KB")

    IO.puts("\n  Files:")
    Enum.each(files, fn f ->
      size_kb = Float.round((f["size"] || 0) / 1024, 2)
      Explorer.info("#{f["name"]} (#{size_kb} KB) - #{f["id"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 4.2 Get file details
Explorer.subheader("4.2 File Details")
case DataFiles.list(config: config, limit: 1) do
  {:ok, %{"data" => [file | _]}} ->
    case DataFiles.get(file["id"], config: config) do
      {:ok, details} ->
        Explorer.success("File: #{details["name"]}")
        Enum.each(details, fn {k, v} ->
          Explorer.info("#{k}: #{inspect(v)}")
        end)
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No files to inspect")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 4.3 Storage quotas
Explorer.subheader("4.3 Storage Quotas")
case DataFiles.get_quotas(config: config) do
  {:ok, quotas} ->
    Explorer.success("Quotas:")
    Enum.each(quotas, fn {k, v} ->
      if is_integer(v) && v > 0 do
        gb = Float.round(v / (1024 * 1024 * 1024), 4)
        Explorer.info("#{k}: #{v} bytes (#{gb} GB)")
      else
        Explorer.info("#{k}: #{inspect(v)}")
      end
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 4.4 Data connections
Explorer.subheader("4.4 Data Connections")
case DataFiles.list_connections(config: config) do
  {:ok, %{"data" => connections}} ->
    Explorer.success("Found #{length(connections)} connections")

    # Group by type
    by_type = Enum.group_by(connections, & &1["type"])
    Enum.each(by_type, fn {type, list} ->
      Explorer.info("#{type}: #{length(list)} connections")
    end)

    # Show unique names
    unique_names = connections |> Enum.map(& &1["name"]) |> Enum.uniq()
    IO.puts("\n  Unique connection names:")
    Enum.each(unique_names, &Explorer.info/1)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 4.5 Find file by name
Explorer.subheader("4.5 Search Files by Name")
case DataFiles.find_by_name(test_filename, config: config) do
  {:ok, file} ->
    Explorer.success("Found: #{file["name"]} (#{file["id"]})")
  {:error, %Error{type: :file_not_found}} ->
    Explorer.info("File not found (expected if no QVD files)")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 5: USERS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 5: USERS API")

# 5.1 List users
Explorer.subheader("5.1 List Users")
case Users.list(config: config, limit: 20) do
  {:ok, %{"data" => users}} ->
    Explorer.success("Found #{length(users)} users")
    Enum.take(users, 5) |> Enum.each(fn u ->
      Explorer.info("#{u["name"]} (#{u["email"]}) - #{u["status"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 5.2 Get current user
Explorer.subheader("5.2 Current User (Me)")
case Users.me(config: config) do
  {:ok, user} ->
    Explorer.success("Current user: #{user["name"]}")
    Explorer.info("ID: #{user["id"]}")
    Explorer.info("Email: #{user["email"]}")
    Explorer.info("Status: #{user["status"]}")
    Explorer.info("Subject: #{user["subject"]}")
    Explorer.info("Tenant ID: #{user["tenantId"]}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 5.3 User count
Explorer.subheader("5.3 User Count")
case Users.count(config: config) do
  {:ok, count} ->
    Explorer.success("Total users: #{inspect(count)}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 6: API KEYS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 6: API KEYS API")

# 6.1 List API keys
Explorer.subheader("6.1 List API Keys")
case APIKeys.list(config: config, limit: 20) do
  {:ok, %{"data" => keys}} ->
    Explorer.success("Found #{length(keys)} API keys")
    Enum.take(keys, 5) |> Enum.each(fn k ->
      Explorer.info("#{k["description"]} - Created: #{k["createdAt"]} - Last used: #{k["lastUsed"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 6.2 API keys config (requires tenant_id)
Explorer.subheader("6.2 API Keys Configuration")
case Tenants.me(config: config) do
  {:ok, tenant} ->
    case APIKeys.get_config(tenant["id"], config: config) do
      {:ok, api_config} ->
        Explorer.success("API Keys config:")
        Enum.each(api_config, fn {k, v} ->
          Explorer.info("#{k}: #{inspect(v)}")
        end)
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:error, err} ->
    Explorer.error("Could not get tenant ID: #{inspect(err)}")
end

# =============================================================================
# SECTION 7: AUTOMATIONS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 7: AUTOMATIONS API")

# 7.1 List automations
Explorer.subheader("7.1 List Automations")
case Automations.list(config: config, limit: 20) do
  {:ok, %{"data" => automations}} ->
    Explorer.success("Found #{length(automations)} automations")

    # Group by state
    by_state = Enum.group_by(automations, & &1["state"])
    Enum.each(by_state, fn {state, list} ->
      Explorer.info("#{state || "unknown"}: #{length(list)}")
    end)

    IO.puts("\n  Automations:")
    Enum.take(automations, 5) |> Enum.each(fn a ->
      Explorer.info("#{a["name"]} (#{a["state"]}) - #{a["id"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 7.2 Get automation details
Explorer.subheader("7.2 Automation Details")
case Automations.list(config: config, limit: 1) do
  {:ok, %{"data" => [automation | _]}} ->
    case Automations.get(automation["id"], config: config) do
      {:ok, details} ->
        Explorer.success("Automation: #{details["name"]}")
        Explorer.info("ID: #{details["id"]}")
        Explorer.info("State: #{details["state"]}")
        Explorer.info("Run mode: #{details["runMode"]}")
        Explorer.info("Created: #{details["createdAt"]}")
        Explorer.info("Updated: #{details["updatedAt"]}")
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No automations found")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 7.3 Automation usage
Explorer.subheader("7.3 Automation Usage Statistics")
case Automations.get_usage(config: config) do
  {:ok, usage} ->
    Explorer.success("Usage statistics:")
    Enum.each(usage, fn {k, v} ->
      Explorer.info("#{k}: #{inspect(v)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 7.4 Automation runs
Explorer.subheader("7.4 Recent Automation Runs")
case Automations.list(config: config, limit: 1) do
  {:ok, %{"data" => [automation | _]}} ->
    case Automations.list_runs(automation["id"], config: config, limit: 5) do
      {:ok, %{"data" => runs}} ->
        Explorer.success("Found #{length(runs)} runs for '#{automation["name"]}'")
        Enum.each(runs, fn r ->
          Explorer.info("#{r["status"]} | #{r["startTime"]} - #{r["stopTime"]}")
        end)
      {:ok, runs} when is_list(runs) ->
        Explorer.success("Found #{length(runs)} runs")
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No automations to check runs")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 8: WEBHOOKS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 8: WEBHOOKS API")

# 8.1 List webhooks
Explorer.subheader("8.1 List Webhooks")
case Webhooks.list(config: config, limit: 20) do
  {:ok, %{"data" => webhooks}} ->
    Explorer.success("Found #{length(webhooks)} webhooks")
    Enum.take(webhooks, 5) |> Enum.each(fn w ->
      enabled = if w["enabled"], do: "enabled", else: "disabled"
      Explorer.info("#{w["name"]} (#{enabled}) - #{w["url"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 8.2 Available event types
Explorer.subheader("8.2 Available Webhook Event Types")
case Webhooks.list_event_types(config: config) do
  {:ok, %{"data" => types}} ->
    Explorer.success("Found #{length(types)} event types")
    # Group by category (first part of event name)
    by_category = types |> Enum.group_by(fn t ->
      t["eventType"] |> String.split(".") |> Enum.take(3) |> Enum.join(".")
    end)
    Enum.each(by_category, fn {category, list} ->
      Explorer.info("#{category}: #{length(list)} events")
    end)
  {:ok, types} when is_list(types) ->
    Explorer.success("Found #{length(types)} event types")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 8.3 Webhook deliveries
Explorer.subheader("8.3 Webhook Deliveries")
case Webhooks.list(config: config, limit: 1) do
  {:ok, %{"data" => [webhook | _]}} ->
    case Webhooks.list_deliveries(webhook["id"], config: config, limit: 5) do
      {:ok, %{"data" => deliveries}} ->
        Explorer.success("Found #{length(deliveries)} deliveries for '#{webhook["name"]}'")
        Enum.each(deliveries, fn d ->
          Explorer.info("#{d["status"]} | #{d["triggeredAt"]} | Event: #{d["eventType"]}")
        end)
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No webhooks to check deliveries")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 9: DATA CONNECTIONS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 9: DATA CONNECTIONS API")

# 9.1 List data connections
Explorer.subheader("9.1 List Data Connections")
case DataConnections.list(config: config, limit: 50) do
  {:ok, %{"data" => connections}} ->
    Explorer.success("Found #{length(connections)} data connections")

    # Group by type
    by_type = Enum.group_by(connections, & &1["qType"])
    Enum.each(by_type, fn {type, list} ->
      Explorer.info("#{type}: #{length(list)} connections")
    end)

    IO.puts("\n  Sample connections:")
    Enum.take(connections, 5) |> Enum.each(fn c ->
      Explorer.info("#{c["qName"]} (#{c["qType"]}) - Space: #{c["spaceId"] || "personal"}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 9.2 Data connection details
Explorer.subheader("9.2 Data Connection Details")
case DataConnections.list(config: config, limit: 1) do
  {:ok, %{"data" => [conn | _]}} ->
    case DataConnections.get(conn["id"], config: config) do
      {:ok, details} ->
        Explorer.success("Connection: #{details["qName"]}")
        Explorer.info("ID: #{details["id"]}")
        Explorer.info("Type: #{details["qType"]}")
        Explorer.info("Space ID: #{details["spaceId"] || "(personal)"}")
        Explorer.info("Owner ID: #{details["ownerId"]}")
        Explorer.info("Created: #{details["createdDate"]}")
        Explorer.info("Modified: #{details["modifiedDate"]}")
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No connections to inspect")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 9.3 Connections by space
Explorer.subheader("9.3 Data Connections in Target Space")
case DataConnections.list(config: config, space_id: target_space_id) do
  {:ok, %{"data" => connections}} ->
    Explorer.success("Found #{length(connections)} connections in target space")
    Enum.each(connections, fn c ->
      Explorer.info("#{c["qName"]} (#{c["qType"]})")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 10: TENANTS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 10: TENANTS API")

# 10.1 Current tenant
Explorer.subheader("10.1 Current Tenant (Me)")
case Tenants.me(config: config) do
  {:ok, tenant} ->
    Explorer.success("Current tenant: #{tenant["name"]}")
    Explorer.info("ID: #{tenant["id"]}")
    Explorer.info("Hostnames: #{inspect(tenant["hostnames"])}")
    Explorer.info("Created: #{tenant["created"]}")
    Explorer.info("Created by: #{tenant["createdByUser"]}")
    Explorer.info("Status: #{tenant["status"]}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 11: GROUPS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 11: GROUPS API")

# 11.1 List groups
Explorer.subheader("11.1 List Groups")
case Groups.list(config: config, limit: 20) do
  {:ok, %{"data" => groups}} ->
    Explorer.success("Found #{length(groups)} groups")
    Enum.take(groups, 10) |> Enum.each(fn g ->
      Explorer.info("#{g["name"]} - #{g["id"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 11.2 Group settings
Explorer.subheader("11.2 Group Settings")
case Groups.list_settings(config: config) do
  {:ok, settings} ->
    Explorer.success("Group settings:")
    Enum.each(settings, fn {k, v} ->
      Explorer.info("#{k}: #{inspect(v)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 12: ROLES API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 12: ROLES API")

# 12.1 List roles
Explorer.subheader("12.1 Available Roles")
case Roles.list(config: config, limit: 50) do
  {:ok, %{"data" => roles}} ->
    Explorer.success("Found #{length(roles)} roles")

    # Group by type
    by_type = Enum.group_by(roles, & &1["type"])
    Enum.each(by_type, fn {type, list} ->
      IO.puts("\n  #{String.upcase(type || "other")} roles (#{length(list)}):")
      Enum.each(list, fn r ->
        Explorer.info("#{r["name"]} - #{r["description"] || "(no description)"}")
      end)
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 12.2 Role details
Explorer.subheader("12.2 Role Details (First Role)")
case Roles.list(config: config, limit: 1) do
  {:ok, %{"data" => [role | _]}} ->
    case Roles.get(role["id"], config: config) do
      {:ok, details} ->
        Explorer.success("Role: #{details["name"]}")
        Explorer.info("ID: #{details["id"]}")
        Explorer.info("Type: #{details["type"]}")
        Explorer.info("Description: #{details["description"]}")
        if details["permissions"] do
          Explorer.info("Permissions: #{length(details["permissions"])} total")
          Enum.take(details["permissions"], 5) |> Enum.each(fn p ->
            Explorer.info("  - #{p}")
          end)
        end
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No roles found")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 13: AUDITS API - Deep Exploration
# =============================================================================
Explorer.header("SECTION 13: AUDITS API")

# 13.1 List recent audit events
Explorer.subheader("13.1 Recent Audit Events")
case Audits.list(config: config, limit: 20) do
  {:ok, %{"data" => events}} ->
    Explorer.success("Found #{length(events)} recent audit events")

    # Group by event type
    by_type = Enum.group_by(events, & &1["eventType"])
    Enum.each(by_type, fn {type, list} ->
      Explorer.info("#{type}: #{length(list)} events")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 13.2 Audit sources
Explorer.subheader("13.2 Available Audit Sources")
case Audits.list_sources(config: config) do
  {:ok, %{"data" => sources}} ->
    Explorer.success("Found #{length(sources)} audit sources")
    Enum.each(sources, fn s ->
      Explorer.info("#{s["id"]} - #{s["name"]}")
    end)
  {:ok, sources} when is_list(sources) ->
    Explorer.success("Found #{length(sources)} sources")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 13.3 Audit event types
Explorer.subheader("13.3 Available Audit Event Types")
case Audits.list_types(config: config) do
  {:ok, %{"data" => types}} ->
    Explorer.success("Found #{length(types)} event types")
    # Group by category
    by_category = types |> Enum.group_by(fn t ->
      (t["eventType"] || "") |> String.split(".") |> Enum.take(3) |> Enum.join(".")
    end)
    Enum.each(by_category, fn {category, list} ->
      Explorer.info("#{category}: #{length(list)} types")
    end)
  {:ok, types} when is_list(types) ->
    Explorer.success("Found #{length(types)} event types")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 13.4 Audit settings
Explorer.subheader("13.4 Audit Settings")
case Audits.get_settings(config: config) do
  {:ok, settings} ->
    Explorer.success("Audit settings:")
    Enum.each(settings, fn {k, v} ->
      Explorer.info("#{k}: #{inspect(v)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 14: ITEMS API (Unified Resources) - Phase 4
# =============================================================================
Explorer.header("SECTION 14: ITEMS API (Unified Resources)")

# 14.1 List all items
Explorer.subheader("14.1 List All Items")
case Items.list(config: config, limit: 20) do
  {:ok, %{"data" => items}} ->
    Explorer.success("Found #{length(items)} items")

    # Group by resource type
    by_type = Enum.group_by(items, & &1["resourceType"])
    Enum.each(by_type, fn {type, list} ->
      Explorer.info("#{type}: #{length(list)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 14.2 Filter by resource type
Explorer.subheader("14.2 Items by Resource Type")
["app", "space", "genericlink", "datafile"] |> Enum.each(fn type ->
  case Items.list(config: config, resource_type: type, limit: 5) do
    {:ok, %{"data" => items}} ->
      Explorer.info("#{type}: #{length(items)} items")
    {:error, _} ->
      Explorer.info("#{type}: query failed")
  end
end)

# 14.3 Item details
Explorer.subheader("14.3 Item Details")
case Items.list(config: config, limit: 1) do
  {:ok, %{"data" => [item | _]}} ->
    case Items.get(item["id"], config: config) do
      {:ok, details} ->
        Explorer.success("Item: #{details["name"]}")
        Explorer.info("ID: #{details["id"]}")
        Explorer.info("Resource Type: #{details["resourceType"]}")
        Explorer.info("Resource ID: #{details["resourceId"]}")
        Explorer.info("Owner ID: #{details["ownerId"]}")
        Explorer.info("Space ID: #{details["spaceId"]}")
        Explorer.info("Created: #{details["createdAt"]}")
        Explorer.info("Updated: #{details["updatedAt"]}")
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No items found")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 14.4 Collections for an item
Explorer.subheader("14.4 Collections Containing Item")
case Items.list(config: config, resource_type: "app", limit: 1) do
  {:ok, %{"data" => [item | _]}} ->
    case Items.get_collections(item["id"], config: config) do
      {:ok, %{"data" => collections}} ->
        Explorer.success("Item '#{item["name"]}' is in #{length(collections)} collections")
      {:ok, _} ->
        Explorer.info("No collections for this item")
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No items to check")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 15: COLLECTIONS API - Phase 4
# =============================================================================
Explorer.header("SECTION 15: COLLECTIONS API")

# 15.1 List all collections
Explorer.subheader("15.1 List All Collections")
case Collections.list(config: config, limit: 20) do
  {:ok, %{"data" => collections}} ->
    Explorer.success("Found #{length(collections)} collections")

    # Group by type
    by_type = Enum.group_by(collections, & &1["type"])
    Enum.each(by_type, fn {type, list} ->
      Explorer.info("#{type}: #{length(list)}")
    end)

    IO.puts("\n  Collections:")
    Enum.take(collections, 5) |> Enum.each(fn c ->
      Explorer.info("#{c["name"]} (#{c["type"]}) - #{c["itemCount"] || 0} items")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 15.2 Favorites collection
Explorer.subheader("15.2 Favorites Collection")
case Collections.get_favorites(config: config) do
  {:ok, favorites} ->
    Explorer.success("Favorites collection:")
    Explorer.info("ID: #{favorites["id"]}")
    Explorer.info("Name: #{favorites["name"]}")
    Explorer.info("Item count: #{favorites["itemCount"] || 0}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 15.3 Collection details and items
Explorer.subheader("15.3 Collection Details")
case Collections.list(config: config, limit: 1) do
  {:ok, %{"data" => [coll | _]}} ->
    case Collections.get(coll["id"], config: config) do
      {:ok, details} ->
        Explorer.success("Collection: #{details["name"]}")
        Explorer.info("ID: #{details["id"]}")
        Explorer.info("Type: #{details["type"]}")
        Explorer.info("Description: #{details["description"] || "(none)"}")
        Explorer.info("Item count: #{details["itemCount"] || 0}")
        Explorer.info("Owner ID: #{details["ownerId"]}")
      {:error, err} ->
        Explorer.error(inspect(err))
    end

    case Collections.list_items(coll["id"], config: config, limit: 5) do
      {:ok, %{"data" => items}} ->
        Explorer.info("Items in collection: #{length(items)}")
        Enum.each(items, fn item ->
          Explorer.info("  - #{item["name"]} (#{item["resourceType"]})")
        end)
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No collections to inspect")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 16: REPORTS API - Phase 4
# =============================================================================
Explorer.header("SECTION 16: REPORTS API")

# 16.1 List all reports
Explorer.subheader("16.1 List All Reports")
case Reports.list(config: config, limit: 20) do
  {:ok, %{"data" => reports}} ->
    Explorer.success("Found #{length(reports)} reports")

    # Group by status
    by_status = Enum.group_by(reports, & &1["status"])
    Enum.each(by_status, fn {status, list} ->
      Explorer.info("#{status}: #{length(list)}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 16.2 Report details
Explorer.subheader("16.2 Report Details")
case Reports.list(config: config, limit: 1) do
  {:ok, %{"data" => [report | _]}} ->
    case Reports.get(report["id"], config: config) do
      {:ok, details} ->
        Explorer.success("Report: #{details["name"] || details["id"]}")
        Explorer.info("ID: #{details["id"]}")
        Explorer.info("Status: #{details["status"]}")
        Explorer.info("App ID: #{details["appId"]}")
        Explorer.info("Type: #{details["type"]}")
        Explorer.info("Created: #{details["createdAt"]}")
      {:error, err} ->
        Explorer.error(inspect(err))
    end
  {:ok, _} ->
    Explorer.info("No reports found")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 16.3 Reports for target app
Explorer.subheader("16.3 Reports for Target App")
case Reports.list(config: config, app_id: target_app_id, limit: 10) do
  {:ok, %{"data" => reports}} ->
    Explorer.success("Found #{length(reports)} reports for target app")
    Enum.each(reports, fn r ->
      Explorer.info("#{r["status"]} | #{r["type"]} | #{r["createdAt"]}")
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 17: NATURAL LANGUAGE API - Phase 4
# =============================================================================
Explorer.header("SECTION 17: NATURAL LANGUAGE API (Insight Advisor)")

# 17.1 List available analysis types
Explorer.subheader("17.1 Available Analysis Types")
case NaturalLanguage.list_analysis_types(target_app_id, config: config) do
  {:ok, %{"data" => types}} ->
    Explorer.success("Found #{length(types)} analysis types")
    Enum.each(types, fn t ->
      Explorer.info("#{t["type"]}: #{t["shortDescription"]}")
    end)
  {:ok, response} ->
    Explorer.info("Response: #{inspect(response)}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 17.2 Get NL model status
Explorer.subheader("17.2 NL Model Status")
case NaturalLanguage.get_model(target_app_id, config: config) do
  {:ok, model} ->
    Explorer.success("NL Model status:")
    Explorer.info("Status: #{model["status"]}")
    Explorer.info("Last updated: #{model["lastUpdated"]}")
    Explorer.info("Languages: #{inspect(model["languages"])}")
    if model["vocabulary"] do
      Explorer.info("Vocabulary terms: #{model["vocabulary"]["terms"]}")
      Explorer.info("Synonyms: #{model["vocabulary"]["synonyms"]}")
    end
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 17.3 Get recommendations via recommend/3
Explorer.subheader("17.3 Analysis Recommendations")
case NaturalLanguage.recommend(target_app_id, %{"text" => "show sales"}, config: config) do
  {:ok, %{"data" => recs}} ->
    Explorer.success("Found #{length(recs)} recommendations for 'show sales'")
    Enum.take(recs, 5) |> Enum.each(fn r ->
      Explorer.info("#{r["type"]}: #{inspect(r["analysis"])}")
    end)
  {:ok, response} ->
    Explorer.info("Response: #{inspect(response)}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 17.4 Ask a question via ask/3
Explorer.subheader("17.4 Natural Language Query")
case NaturalLanguage.ask(target_app_id, "What is the total?", config: config) do
  {:ok, %{"data" => results}} ->
    Explorer.success("Found #{length(results)} results")
    Enum.take(results, 3) |> Enum.each(fn r ->
      Explorer.info("#{r["type"]}: #{inspect(r["analysis"])}")
    end)
  {:ok, response} ->
    Explorer.info("Response: #{inspect(response)}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SECTION 18: CROSS-API ANALYSIS
# =============================================================================
Explorer.header("SECTION 18: CROSS-API ANALYSIS")

# 18.1 Apps per space
Explorer.subheader("18.1 Apps Distribution by Space")
case Spaces.list(config: config, limit: 100) do
  {:ok, %{"data" => spaces}} ->
    Enum.each(Enum.take(spaces, 10), fn space ->
      case Apps.list(config: config, space_id: space["id"], limit: 100) do
        {:ok, %{"data" => apps}} ->
          Explorer.info("#{space["name"]}: #{length(apps)} apps")
        _ ->
          Explorer.info("#{space["name"]}: error")
      end
    end)
  {:error, err} ->
    Explorer.error(inspect(err))
end

# 18.2 Reload success rate
Explorer.subheader("18.2 Reload Success Rate (Last 50)")
case Reloads.list(config: config, limit: 50) do
  {:ok, %{"data" => reloads}} ->
    total = length(reloads)
    succeeded = Enum.count(reloads, & &1["status"] == "SUCCEEDED")
    failed = Enum.count(reloads, & &1["status"] == "FAILED")
    rate = if total > 0, do: Float.round(succeeded / total * 100, 1), else: 0

    Explorer.success("Success rate: #{rate}%")
    Explorer.info("Succeeded: #{succeeded}")
    Explorer.info("Failed: #{failed}")
    Explorer.info("Other: #{total - succeeded - failed}")
  {:error, err} ->
    Explorer.error(inspect(err))
end

# =============================================================================
# SUMMARY
# =============================================================================
Explorer.header("EXPLORATION COMPLETE")
IO.puts("""

Summary of QlikElixir REST API capabilities tested:

PHASE 1 APIs:
  APPS API:
    - list (with pagination, filters)
    - get (detailed app info)
    - get_metadata (data model info)
    - get_lineage (data sources)

  SPACES API:
    - list (with type filter)
    - get (space details)
    - list_assignments (access control)
    - list_types

  RELOADS API:
    - list (with app_id/status filters)
    - get (reload details)

  DATA FILES API:
    - list (with connection filter)
    - get (file details)
    - get_quotas
    - list_connections
    - find_by_name

PHASE 2 APIs:
  USERS API:
    - list (with pagination)
    - me (current user)
    - count (user statistics)

  API KEYS API:
    - list (all keys)
    - get_config (API keys configuration)

  AUTOMATIONS API:
    - list (with state filters)
    - get (automation details)
    - get_usage (usage statistics)
    - list_runs (execution history)

  WEBHOOKS API:
    - list (all webhooks)
    - list_event_types (available events)
    - list_deliveries (webhook deliveries)

  DATA CONNECTIONS API:
    - list (with space/type filters)
    - get (connection details)

PHASE 3 APIs (Governance & Admin):
  TENANTS API:
    - me (current tenant)

  GROUPS API:
    - list (all groups)
    - list_settings (group settings)

  ROLES API:
    - list (available roles)
    - get (role details with permissions)

  AUDITS API:
    - list (recent audit events)
    - list_sources (audit sources)
    - list_types (event types)
    - get_settings (audit settings)

PHASE 4 APIs (Content & Advanced):
  ITEMS API (Unified Resources):
    - list (with resource_type, space_id, name filters)
    - get (item details)
    - get_collections (collections containing item)
    - get_published_items

  COLLECTIONS API:
    - list (with name, type, sort filters)
    - get (collection details)
    - get_favorites (favorites collection)
    - list_items (items in collection)

  REPORTS API:
    - list (with app_id, status filters)
    - get (report details)
    - download (get download URL)
    - get_status (report generation status)

  NATURAL LANGUAGE API (Insight Advisor):
    - list_analysis_types (available analysis types)
    - get_model (NL model info with fields)
    - recommend (analysis recommendations)
    - ask (natural language queries)

QIX ENGINE:
  - Session management (WebSocket via gun)
  - Protocol encoding/decoding (JSON-RPC 2.0)

Note: Write operations (create, update, delete) were NOT tested per request.
Note: QIX Engine data extraction requires active app connection.
""")
