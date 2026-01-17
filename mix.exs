defmodule QlikElixir.MixProject do
  use Mix.Project

  @version "0.3.2"
  @github_url "https://github.com/dgilperez/qlik_elixir"

  def project do
    [
      app: :qlik_elixir,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:req, "~> 0.5.0"},
      {:jason, "~> 1.4"},
      {:gun, "~> 2.1"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
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
