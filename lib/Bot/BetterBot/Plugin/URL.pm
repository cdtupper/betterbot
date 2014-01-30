package Bot::BetterBot::Plugin::URL;

use strict;
use warnings;

use namespace::autoclean;
use Moose;
use URI::Title qw/title/;
use URI::Find::Simple qw/list_uris/;

extends 'Bot::BetterBot::Plugin';


override on_msg => sub {
   my ($self, $msg) = @_;
   my $reply = '';
   my $i = 1;

   # parse message for URIs
   my @uris = list_uris($msg->{body}); 
   my $count = scalar(@uris);

   foreach (@uris) {
      my $uri = URI->new($_);
      
      # skip if URI isn't valid for some reason
      next unless $uri;
      # don't let clever users read the filesystem
      next if $uri->scheme eq 'file';
      
      my $title = title($_);
      next unless $title;
      
      # if there are multiple URLS, return "1. [First Title] 2. [Second Title ...]" string
      if ($count > 1) { $reply .= "$i. [ $title ] "; }
      # else just return the title
      else { $reply = "Title: $title"; }

      $i++;
   }

   return $reply if $reply;
};


__PACKAGE__->meta->make_immutable;

1;
