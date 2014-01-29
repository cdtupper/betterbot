package Bot::BetterBot::Plugin;

use Moose;
use namespace::autoclean;

use warnings;
use strict;

has 'name' => (
   isa      => 'Str',
   is       => 'ro',
   required => 1,
);

has 'bot' => (
   isa      => 'Bot::BetterBot',
   is       => 'ro',
   required => 1,
);

sub say {
   my $self = shift;
   return $self->bot->say(@_);
}

sub reply {
   my $self = shift;
   return $self->bot->reply(@_);
}

sub emote {
   my $self = shift;
   return $self->bot->emote(@_);
}

sub notice {
   my $self = shift;
   return $self->bot->notice(@_);
}

sub get_var {
   my $self = shift;
   return $self->bot->get_var(@_);
}

sub set_var {
   my $self = shift;
   return $self->bot->set_var(@_);
}

### Override the following methods in your plugin ###

sub help {
   my $self = shift;
   return "Plugin '$self->name' has no defined help.";
}

sub on_load    { undef }  # called when this plugin is loaded. init code goes here.
sub on_connect { undef }  # called when bot connects to a server
sub on_join    { undef }  # called when a user joins a channel
sub on_part    { undef }  # called when a user leaves a channel
sub on_msg     { undef }  # called when a user speaks in a channel or privmsg
sub on_emote   { undef }  # called when a user emotes
sub on_notice  { undef }  # called when a notice is recieved
sub on_kick    { undef }  # called when a user is kicked
sub on_quit    { undef }  # called when a user quits
sub on_nick    { undef }  # called when a user changes nicks
sub on_topic   { undef }  # called when a channel's topic is changed
sub on_unload  { undef }  # called when this plugin is unloaded. perform cleanup here. 


__PACKAGE__->meta->make_immutable;

1;
