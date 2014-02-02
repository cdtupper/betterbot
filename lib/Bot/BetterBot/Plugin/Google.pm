package Bot::BetterBot::Plugin::Google;

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use WWW::Google::CustomSearch;

extends 'Bot::BetterBot::Plugin';

my $api_key;
my $cx;
my $google;
my $google_image;

override on_load => sub {
   my $self = shift;
   
   $api_key = $self->get_var('google_api_key');
   $cx      = $self->get_var('google_cx_id');

   unless ($api_key and $cx) {
      die 'Google API keys missing. Please ensure you have defined google_api_key ',
          'and google_cx_id in the \'store\' section of the config file.';
   }
   
   $google = WWW::Google::CustomSearch->new({
      api_key     => $api_key,
      cx          => $cx,
      lr          => 'lang_en',
      num         => 1,
      prettyprint => 'false',
   });
   $google_image = WWW::Google::CustomSearch->new({
      api_key     => $api_key,
      cx          => $cx,
      lr          => 'lang_en',
      num         => 1,
      prettyprint => 'false',
      search_type => 'image'
   });
};

override on_msg => sub {
   my ($self, $msg) = @_;
   
   my ($cmd, $query) = $self->parse_cmd($msg);

   if ($cmd eq 'google' or $cmd eq 'g') {
      return 'You must specify a search query.' unless $query;
      
      my $result = $google->search($query);

      my $link  = $result->raw->{items}->[0]->{link};
      my $title = $result->raw->{items}->[0]->{title};
      my $desc  = $result->raw->{items}->[0]->{snippet};
      $desc =~ s/\R//g;

      return "$link :: $title :: $desc";
   }

   if ($cmd eq 'googleimage' or $cmd eq 'gi') {
      return 'You must specify a search query.' unless $query;
      my $result = $google_image->search($query);
      return $result->raw->{items}->[0]->{link};
   }
};

__PACKAGE__->meta->make_immutable;

1;
