package Bot::BetterBot::Plugin::Twitter;

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use Net::Twitter::Lite::WithAPIv1_1;

extends 'Bot::BetterBot::Plugin';

my $consumer_key;
my $consumer_secret;
my $access_token;
my $access_token_secret;
my $twitter;

override on_load => sub {
   my $self = shift;
   
   $consumer_key        = $self->get_var('twitter_consumer_key');
   $consumer_secret     = $self->get_var('twitter_consumer_secret');
   $access_token        = $self->get_var('twitter_access_token');
   $access_token_secret = $self->get_var('twitter_access_token_secret');

   unless ($consumer_key and $consumer_secret and $access_token and $access_token_secret) {
      die  ' Please ensure you have defined ' .
           ' twitter_consumer_key, twitter_consumer_secret, twitter_access_token, and ' .
           ' twitter_access_token_secret in the \'store\' section of the config file.';
   }
   
   $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
      consumer_key        => $consumer_key,
      consumer_secret     => $consumer_secret,
      access_token        => $access_token,
      access_token_secret => $access_token_secret,
      ssl                 => 1,
  );      
};

override on_msg => sub {
   my ($self, $msg) = @_;
   
   # check if message is "betterbot: tweet" or "!tweet"
   if (( $msg->{prefix} and $msg->{body} =~ /^tweet\s+(.*)/ )  
         or ( $msg->{body} =~ /^!tweet\s+(.*)/ )) {
      
      my $tweet_body = $1;

      unless ($tweet_body) {
         $self->reply($msg, 'You must specify a message to tweet.');
         return;
      }
      
      # post our tweet to the twitter API
      my $result;
      eval { $result = $twitter->update($tweet_body); };

      # check if API sent back an error code
      if ( my $err = $@ ) {
         die $@ unless blessed $err && $err->isa('Net::Twitter::Lite::Error');
         my $error = $err->error;
         $self->reply($msg, "Could not post to Twitter: $error");
         return;
      }

      # else, tweet posted sucessfully. reply with permalink
      $self->reply($msg, 'Tweet posted successfully: https://twitter.com/' .
         $result->{user}->{id_str} . '/status/' . $result->{id_str}
      );
   }
};

__PACKAGE__->meta->make_immutable;

1;
