package Bot::BetterBot::Plugin::Echo;

use strict;
use warnings;

use namespace::autoclean;
use Moose;

extends 'Bot::BetterBot::Plugin';

override on_msg => sub {
   my ($self, $msg) = @_;
   my ($cmd, $args) = $self->parse_cmd($msg);

   if ($cmd eq 'echo') {
      return "You must specify a string to echo." unless $args;
      return $args;
   }
};

__PACKAGE__->meta->make_immutable;

1;
