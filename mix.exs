defmodule QlikElixir.MixProject do
  use Mix.Project

  @version "0.2.2"
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
    "An Elixir client library for uploading CSV files to Qlik Cloud with comprehensive API support"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url
      },
      maintainers: ["dgilperez"],
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
