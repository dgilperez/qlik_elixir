defmodule QlikElixir.MixProject do
  use Mix.Project

  @version "0.4.1"
  @github_url "https://github.com/dgilperez/qlik_elixir"

  def project do
    [
      app: :qlik_elixir,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Floor at the current total (65.86%) so CI catches regressions; the
      # target in CLAUDE.md is 90%. Raise it as coverage grows.
      test_coverage: [summary: [threshold: 65]],
      hex: [ignore_advisories: Enum.map(advisory_exceptions(), & &1.id)],
      docs: docs(),
      package: package(),
      description: description(),
      source_url: @github_url,
      homepage_url: @github_url,
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:gun, "~> 2.1"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  # `mix hex.audit` exceptions for advisories with no fixed release yet. Each one
  # expires: test/advisory_exceptions_test.exs fails the suite once it lapses, so
  # the package gets upgraded or the exception renewed with a fresh reason.
  def advisory_exceptions do
    [
      %{
        id: "EEF-CVE-2026-43966",
        package: "cowlib",
        until: ~D[2026-12-05],
        reason:
          "No fixed release yet. The flaw is in cow_http_struct_hd:escape_string/2, reached only when serializing structured headers (variants, variant-key, WebTransport protocols); gun never calls those serializers and this library builds no structured headers."
      },
      %{
        id: "GHSA-w4f7-4cxr-rv3c",
        package: "gun",
        until: ~D[2026-12-05],
        reason:
          "No fixed release yet. Same root cause as EEF-CVE-2026-43966 (cowlib's cow_http_struct_hd); the QIX WebSocket client never sends structured headers built from user input."
      }
    ]
  end

  defp description do
    "Comprehensive Elixir client for Qlik Cloud REST APIs and QIX Engine"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url,
        "Qlik Developer Portal" => "https://qlik.dev/"
      },
      maintainers: ["dgilperez"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md guides)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: @github_url,
      main: "readme",
      logo: nil,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "guides/getting-started.md",
        "guides/rest-apis.md",
        "guides/qix-engine.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "REST APIs": [
          QlikElixir.REST.Apps,
          QlikElixir.REST.Spaces,
          QlikElixir.REST.DataFiles,
          QlikElixir.REST.Reloads,
          QlikElixir.REST.Users,
          QlikElixir.REST.Groups,
          QlikElixir.REST.APIKeys,
          QlikElixir.REST.Automations,
          QlikElixir.REST.Webhooks,
          QlikElixir.REST.DataConnections,
          QlikElixir.REST.Items,
          QlikElixir.REST.Collections,
          QlikElixir.REST.Reports,
          QlikElixir.REST.ReportTemplates,
          QlikElixir.REST.Tenants,
          QlikElixir.REST.Roles,
          QlikElixir.REST.Audits,
          QlikElixir.REST.NaturalLanguage
        ],
        "QIX Engine": [
          QlikElixir.QIX.Session,
          QlikElixir.QIX.App,
          QlikElixir.QIX.Protocol
        ],
        Core: [
          QlikElixir,
          QlikElixir.Config,
          QlikElixir.Error,
          QlikElixir.Pagination
        ],
        Internal: [
          QlikElixir.Client,
          QlikElixir.REST.Helpers
        ]
      ]
    ]
  end
end
