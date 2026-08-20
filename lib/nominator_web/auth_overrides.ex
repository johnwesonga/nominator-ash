defmodule NominatorWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  # override AshAuthentication.Phoenix.Components.Banner do
  #   set :image_url, "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
  #   set :text_class, "bg-red-500"
  # end

  # override AshAuthentication.Phoenix.Components.SignIn do
  #  set :show_banner, false
  # end

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/nominator.png"
    set :dark_image_url, "/images/nominator.png"
    set :href_url, "/"
    # set :text, "Most Inspirational Swimmer"
    set :image_class, "mx-auto h-16 w-auto"
    set :dark_image_class, "mx-auto hidden h-16 w-auto dark:block"
    set :text_class, "mt-3 text-center text-sm text-[#5A7684]"
  end
end
