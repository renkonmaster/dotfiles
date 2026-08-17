_:

{
  # Kept during migration because the live ~/.aliases link still targets it.
  home.file.".aliases".source = ../home/.aliases;

  # Starship itself remains managed by mise; Home Manager owns only this file.
  xdg.configFile."starship.toml".source = ../config/starship.toml;
}
