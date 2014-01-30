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


# pass through IRC commands to our bot ref
sub say     { shift->bot->say(@_);     }
sub reply   { shift->bot->reply(@_);   }
sub emote   { shift->bot->emote(@_);   }
sub notice  { shift->bot->notice(@_);  }
sub get_var { shift->bot->get_var(@_); }
sub set_var { shift->bot->set_var(@_); }


# returns (command, args) for channel messages of the form "betterbot: command args" and
# "!command args", and for private messages of the form "command args" and "!command args"
sub parse_cmd {
   my ($self, $msg) = @_;

   if (($msg->{prefix} or $msg->{channel} eq 'msg') 
         and $msg->{body} =~ /^([a-zA-Z0-9_]+)\s+(.*)$/ ) {
      return ($1, $2);

   } elsif ($msg->{body} =~ /^!([a-zA-Z0-9_]+)\s+(.*)$/ ) {
      return ($1, $2);

   } elsif (($msg->{prefix} or $msg->{channel} eq 'msg') 
         and $msg->{body} =~ /^([a-zA-Z0-9_]+)\s*$/ ) {
      return ($1, '');

   } elsif ($msg->{body} =~ /^!([a-zA-Z0-9_]+)\s*$/ ) {
      return ($1, '');

   } else {
      return ('', '');
   }
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
