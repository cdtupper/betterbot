package Bot::BetterBot::Plugin::Echo;

use strict;
use warnings;

use namespace::autoclean;
use Moose;

extends 'Bot::BetterBot::Plugin';

override on_msg => sub {
   my ($self, $msg) = @_;
   
   if ($msg->{body} =~ /!echo\s+(.*)/) {
      $self->reply($msg, $1);
   }
};

__PACKAGE__->meta->make_immutable;

1;
