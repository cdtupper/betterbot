package Bot::BetterBot::Plugin::Loader;

use strict;
use warnings;

use namespace::autoclean;
use Moose;

extends 'Bot::BetterBot::Plugin';


override on_msg => sub {
   my ($self, $msg) = @_;

   my ($cmd, $args) = $self->parse_cmd($msg);

   my ($name) = split(/\s+/, $args);
   $name = ucfirst($name);

   if ($cmd eq 'load') {
      return 'You must specify a plugin to load.' unless $name;
      
      try { $self->bot->load($name); } catch { return "Failed to load $name. Check logs."; };
      return "Plugin '$name' loaded successfully.";
   }
   
   if ($cmd eq 'unload') {
      return 'You must specify a plugin to unload.' unless $name;
      
      try { $self->bot->unload($name); } catch { return "Failed to unload $name. Check logs."; };
      return "Plugin '$name' unloaded successfully.";
   }
   
   if ($cmd eq 'reload') {
      return 'You must specify a plugin to reload.' unless $name;
      
      try { $self->bot->reload($name); } catch { return "Failed to reload $name. Check logs."; };
      return "Plugin '$name' reloaded successfully.";
   }
};

__PACKAGE__->meta->make_immutable;

1;
