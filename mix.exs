defmodule QlikElixir.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/yourusername/qlik_elixir" # TODO: Update with your GitHub URL

  def project do
    [
      app: :qlik_elixir,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      source_url: @github_url,
      homepage_url: @github_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
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
      {:req, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    "An Elixir client library for uploading CSV files to Qlik Cloud with comprehensive API support"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url
      },
      maintainers: ["Your Name"], # TODO: Update with your name
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: @github_url,
      main: "QlikElixir",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [QlikElixir],
        "Internal Modules": [
          QlikElixir.Client,
          QlikElixir.Config,
          QlikElixir.Uploader,
          QlikElixir.Error
        ]
      ]
    ]
  end
end