package Bot::BetterBot::Plugin::Echo;

use strict;
use warnings;

use namespace::autoclean;
use Moose;

extends 'Bot::BetterBot::Plugin';


# this function will be called whenever a user speaks in a channel we're in,
# or sends us a private message
override on_msg => sub {
   my ($self, $msg) = @_;

   # check is message has the form "!command args" or "botname: command args"
   my ($cmd, $args) = $self->parse_cmd($msg);

   if ($cmd eq 'echo') {
      return "You must specify a string to echo." unless $args;
      
      # reply with echo of user's message
      return $args;
   }
};

__PACKAGE__->meta->make_immutable;

1;
