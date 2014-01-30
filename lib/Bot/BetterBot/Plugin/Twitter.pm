package Bot::BetterBot::Plugin::Twitter;

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use Try::Tiny;
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
      die 'Twitter API keys missing. Please ensure you have defined twitter_consumer_key, ',
          'twitter_consumer_secret, twitter_access_token, and twitter_access_token_secret ',
          'in the \'store\' section of the config file.';
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
   my ($cmd, $args) = $self->parse_cmd($msg);

   if ($cmd eq 'tweet') {
      my $tweet_body = $args;

      return 'You must specify a message to tweet.' unless $tweet_body;
      
      # post our tweet to the twitter API
      my $result, my $error;
      try { $result = $twitter->update($tweet_body); } catch { $error = $_->error; };

      # if unsuccessful, reply with error
      return "Could not post to Twitter: $error" unless $result;

      # else, tweet posted sucessfully. reply with permalink
      return 'Tweet posted successfully: ' .
         "https://twitter.com/$result->{user}->{id_str}/status/$result->{id_str}";
   }
};

__PACKAGE__->meta->make_immutable;

1;
