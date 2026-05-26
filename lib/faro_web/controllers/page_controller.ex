defmodule FaroWeb.PageController do
  use FaroWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
