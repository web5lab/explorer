defmodule BlockScoutWeb.Account.AuthController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account
  alias Explorer.Repo.ConfigHelper
  alias Plug.CSRFProtection
  require Logger

  plug(Ueberauth)

  def request(conn, _) do
    not_found(conn)
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: root())
  end

  def profile(conn, _params),
    do: conn |> get_session(:current_user) |> do_profile(conn)

  defp do_profile(nil, conn),
    do: redirect(conn, to: root())

  defp do_profile(%{} = user, conn),
    do: render(conn, :profile, user: user)

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: root())
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        CSRFProtection.get_csrf_token()
        Logger.info("------ callback successful")
        Logger.info("#{inspect(user)}")
        conn
        |> put_session(:current_user, user)
        |> redirect(to: redirect_path(params["path"]))

      {:error, reason} ->
        Logger.info("------ callback failed")
        Logger.info("#{inspect(reason)}")
        conn
        |> put_flash(:error, reason)
        |> redirect(to: root())
    end
  end

  def callback(conn, _) do
    not_found(conn)
  end

  # for importing in other controllers
  def authenticate!(conn) do
    current_user(conn) || redirect(conn, to: root())
  end

  def current_user(%{private: %{plug_session: %{"current_user" => _}}} = conn) do
    if Account.enabled?() do
      get_session(conn, :current_user)
    else
      nil
    end
  end

  def current_user(_), do: nil

  defp root do
    ConfigHelper.network_path()
  end

  defp redirect_path(path) when is_binary(path) do
    case URI.parse(path) do
      %URI{path: "/" <> path} ->
        "/" <> path

      %URI{path: path} when is_binary(path) ->
        "/" <> path

      _ ->
        root()
    end
  end

  defp redirect_path(_), do: root()
end
