package Bot::BetterBot::Plugin::Loader;

use strict;
use warnings;

use namespace::autoclean;
use Moose;
use Try::Tiny;

extends 'Bot::BetterBot::Plugin';


override on_msg => sub {
   my ($self, $msg) = @_;

   my ($cmd, $args) = $self->parse_cmd($msg);

   my ($name) = split(/\s+/, $args);
   $name = ucfirst($name) if $name;

   my $err = '';

   if ($cmd eq 'load') {
      return 'You must specify a plugin to load.' unless $name;
      
      try { $self->bot->load($name); } catch {  $err = $_; };
      return $err if $err;
      return "Plugin '$name' loaded successfully.";
   }
   
   if ($cmd eq 'unload') {
      return 'You must specify a plugin to unload.' unless $name;
      
      try { $self->bot->unload($name); } catch { $err = $_; };
      return $err if $err;
      return "Plugin '$name' unloaded successfully.";
   }
   
   if ($cmd eq 'reload') {
      return 'You must specify a plugin to reload.' unless $name;
      
      try { $self->bot->reload($name); } catch { $err = $_; };
      return $err if $err;
      return "Plugin '$name' reloaded successfully.";
   }
};

__PACKAGE__->meta->make_immutable;

1;
