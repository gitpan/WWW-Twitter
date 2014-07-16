#
# Copyleft 2014 Daniel Torres 
# daniel.torres at owasp.org
# All rights released.

package WWW::Twitter;

use strict;
use warnings FATAL => 'all';
use Carp qw(croak);
use Moose;
use Net::SSL (); # From Crypt-SSLeay
use LWP::UserAgent;
use HTTP::Cookies;

our $VERSION = '1.3';

{
has 'username', is => 'rw', isa => 'Str',default => '';	
has 'password', is => 'rw', isa => 'Str',default => '';	
has 'authenticity_token', is => 'rw', isa => 'Str', default => '';	

has proxy_host      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_port      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_user      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_pass      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_env      => ( isa => 'Str', is => 'rw', default => '' );
has debug      => ( isa => 'Int', is => 'rw', default => 0 );
has browser  => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_browser' );


##### login to twitter #######       
sub login
{
my $self = shift;

my $login_url = "https://twitter.com/login";

my $username = $self->username;
my $password = $self->password;
my $debug = $self->debug;

if ($username eq '' || $password eq '')
{
   croak("username or password missing");
}

my $response = $self->dispatch(url => $login_url,method => 'GET');
my $status = $response->status_line;
print "status $status \n" if ($debug);

if($status =~ /403|500|503/m){
 return $status;
}	 

my $content =$response->decoded_content;
$content =~ /value="(.*?)" name="authenticity_token"/;
my $authenticity_token = $1; 
$self->authenticity_token($authenticity_token);

print "login with $authenticity_token \n " if ($debug);


my $post_data = {'session[username_or_email]' => $username, 
				'session[password]' => $password, 
				authenticity_token => $authenticity_token};
				
$self->browser->default_header('Referer' => $login_url);
$self->browser->default_header('Connection' => 'keep-alive');
$self->browser->default_header('Content-Type' => "application/x-www-form-urlencoded");
$self->browser->default_header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');				

$response = $self->dispatch(url =>"https://twitter.com/sessions",method => 'POST',post_data =>$post_data);
return $status;
}


############## update tweet #####################
sub tweet
{
my $self = shift;
my $debug = $self->debug;

my ($tweet) = @_;
my $tries=0;
my $authenticity_token = $self->authenticity_token;

my $post_data = {place_id 	=> '',
				status => $tweet,
				authenticity_token => $authenticity_token};

$self->browser->default_header('Referer' => "https://twitter.com");
$self->browser->default_header('Connection' => 'keep-alive');
$self->browser->default_header('Content-Type' => "application/x-www-form-urlencoded; charset=UTF-8");
$self->browser->default_header('Accept' => 'application/json, text/javascript, */*; q=0.01');
$self->browser->default_header('X-PHX' => 'true');
$self->browser->default_header('X-Requested-With' => 'XMLHttpRequest');
$self->browser->default_header('Pragma' => 'no-cache');
$self->browser->default_header('Cache-Control' => 'no-cache');


TWEET:
$tries++;
print "tweet: $tweet \n" if ($debug);		
my $response = $self->dispatch(url => "https://twitter.com/i/tweet/create",method => 'POST',post_data =>$post_data);
my $status = $response->status_line;

if($status =~ /500 read timeout/m && $tries <=3){
  goto TWEET;
}
my $content =  $response->decoded_content;
    
$content =~ /data-tweet-id=\\"(.*?)\\"/;
my $id = $1; 

print "id $id \n" if ($debug);
return $id;
}  


##### favorite a twitter update  #######    
sub favorite
{
my $self = shift;
my ($tweet_id) = @_;
my $authenticity_token = $self->authenticity_token;

$self->browser->default_header('Accept' => "application/json, text/javascript, */*; q=0.01");
$self->browser->default_header('Accept-Language' => 'en-us,en;q=0.5');
$self->browser->default_header('Connection' => 'keep-alive');
$self->browser->default_header('Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8');
$self->browser->default_header('X-Requested-With' => 'XMLHttpRequest');
$self->browser->default_header('Referer' => "https://twitter.com");
$self->browser->default_header('Pragma' => "no-cache");
$self->browser->default_header('Cache-Control' => "no-cache");

my $post_data = {id => $tweet_id,
				authenticity_token => $authenticity_token};
		
my $response = $self->dispatch(url => "https://twitter.com/i/tweet/favorite",method => 'POST',post_data =>$post_data);
my $status_line = $response->status_line;
if ($status_line eq '200 OK')
  {return 1}
else
  {return 0} 
}   


##### retweet a twitter update  ####### 
sub retweet
{
my $self = shift;
my $debug = $self->debug;
my ($tweet_id) = @_;
my $authenticity_token = $self->authenticity_token;

$self->browser->default_header('Accept' => "application/json, text/javascript, */*; q=0.01");
$self->browser->default_header('Accept-Language' => 'en-us,en;q=0.5');
$self->browser->default_header('Connection' => 'keep-alive');
$self->browser->default_header('Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8');
$self->browser->default_header('X-Requested-With' => 'XMLHttpRequest');
$self->browser->default_header('Referer' => "https://twitter.com");
$self->browser->default_header('Pragma' => "no-cache");
$self->browser->default_header('Cache-Control' => "no-cache");
$self->browser->default_header('Connection' => "keep-alive");


my $post_data = {id => $tweet_id,
				authenticity_token => $authenticity_token};

		
my $response = $self->dispatch(url => "https://twitter.com/i/tweet/retweet",method => 'POST',post_data =>$post_data);									   
my $status_line = $response->status_line;
if ($status_line eq '200 OK')
  {return 1}
else
  {return 0}  
}  


########## get accounts stats ###########
sub stats
{
my $self = shift;
my $debug = $self->debug;
my $username = $self->username;

if ($username eq '' )
{
   croak("username missing");
}

GET:
my $response = $self->dispatch(url => "https://twitter.com/".$username ,method => 'GET');
my $tatus = $response->status_line;

 if($tatus =~ /500/m){
	 sleep 5;
	 goto GET;
 }
 
my $content = $response->decoded_content;

$content =~ /title="(.*?) Tweets"/;
my $total_status = $1; 

$content =~ /title="(.*?) Following"/;
my $following = $1; 

$content =~ /title="(.*?) Follower"/;
my $followers = $1; 

$content =~ /title="(.*?) Photos\/Videos"/;
my $total_media = $1;

$content =~ /title="(.*?) Favorites"/;
my $favorites = $1;

 return { following => $following, followers => $followers, total_status => $total_status,total_media => $total_media,favorites => $favorites};


}     

###################################### internal functions ###################
sub dispatch {    
my $self = shift;
my $debug = $self->debug;
my %options = @_;

my $url = $options{ url };
my $method = $options{ method };

my $response = '';
if ($method eq 'GET')
  { $response = $self->browser->get($url);}
  
if ($method eq 'POST')
  {     
   my $post_data = $options{ post_data };        
   $response = $self->browser->post($url,$post_data);
  }  
  
if ($method eq 'POST_MULTIPART')
  {    	   
   my $post_data = $options{ post_data }; 
   $response = $self->browser->post($url,Content_Type => 'multipart/form-data', Content => $post_data);           
  } 

if ($method eq 'POST_FILE')
  { 
	my $post_data = $options{ post_data };         	    
    $response = $self->browser->post( $url, Content_Type => 'application/atom+xml', Content => $post_data );                 
  }  
      
  
return $response;
}


########## build browser ##############
sub _build_browser {    
my $self = shift;
my $debug = $self->debug;
print "building browser \n" if ($debug);

my @user_agents = ('Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1',
			  'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.83 Safari/537.1',
			  'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:14.0) Gecko/20100101 Firefox/14.0.1',
			  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_1) AppleWebKit/536.25 (KHTML, like Gecko) Version/6.0 Safari/536.25',
			  'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:15.0) Gecko/20100101 Firefox/15.0.1',
			  'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
			  'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:15.0) Gecko/20100101 Firefox/15.0',
			  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_4) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1',
			  'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1',
			  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_4) AppleWebKit/536.25 (KHTML, like Gecko) Version/6.0 Safari/536.25',
			  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_1) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1',
			  'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1',
			  'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.83 Safari/537.1',
			  'Mozilla/5.0 (Windows NT 5.1; rv:14.0) Gecko/20100101 Firefox/14.0.1',
			  'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.83 Safari/537.1');

my $user_agent = @user_agents[rand($#user_agents+1)];
print "user_agent $user_agent \n" if ($debug);

my $proxy_host = $self->proxy_host;
my $proxy_port = $self->proxy_port;
my $proxy_user = $self->proxy_user;
my $proxy_pass = $self->proxy_pass;
my $proxy_type = $self->proxy_env;


my $browser = LWP::UserAgent->new;
$browser->timeout(10);
$browser->cookie_jar(HTTP::Cookies->new(file => "cookies.txt", autosave => 1));
$browser->show_progress(1);
$browser->default_header('User-Agent' => $user_agent ); 


#################### proxy config #######################
#### if there is problem with the proxy HTTPS_PROXY environment variable is used ($proxy_type = ENV) ###
if ( $proxy_type eq 'ENV' )
{
$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL
$ENV{HTTPS_PROXY} = "http://".$proxy_host.":".$proxy_port;
}
elsif (($proxy_user ne "") && ($proxy_host ne ""))
{
 $browser->proxy(['http', 'https'], 'http://'.$proxy_user.':'.$proxy_pass.'@'.$proxy_host.':'.$proxy_port); # Using a private proxy
}
   elsif ($proxy_host eq "")
   { 
	  print "No proxy \n" if ($debug);  
    }
  else
    {
	 $browser->proxy(['http', 'https'], 'http://'.$proxy_host.':'.$proxy_port);
	 }             

return $browser;     
}

}
1; # End of WWW::Twitter


__END__

=head1 NAME

WWW::Twitter - Twitter interface (Without API).


=head1 SYNOPSIS


Usage:

use WWW::Twitter;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my $twitter = WWW::Twitter->new( username => USERNAME,
					password => PASS);
					

$twitter->login; 

$mystatus_id = $twitter->tweet('my first status');
print "mystatus_id $mystatus_id \n";


=head1 DESCRIPTION

Twitter::Shell Twitter interface. Do not make use of twitter API (Only username and password required)

=head1 FUNCTIONS

=head2 constructor

    my $twitter = WWW::Twitter->new( username => USERNAME,
					password => PASS);

=head2 login

    $twitter->login;

Login to the twitter account with the username and password provided. You MUST call this function before call any other function.

=head2 tweet

    $mystatus_id = $twitter->tweet('my first status');

Make a tweet and return the tweet id

=head2 favorite

   $status = $twitter->favorite($status_id);
   print "favorite status $status \n"; # 1 = OK ; 0 = Something wrong

Mark as favorite a tweet. The functions needs the status id as a parameter. Return 1 if sucessful and 0 if something went wrong
   
=head2 retweet

   $status = $twitter->retweet($status_id);
   print "favorite status $status \n"; # 1 = OK ; 0 = Something wrong

Make a retweet of an update. The functions needs the status id as a parameter. Return 1 if sucessful and 0 if something went wrong
   
=head2 stats

   $stats = $twitter->stats;	
   $following = $stats->{following}/;
   $followers = $stats->{followers};	
   $total_status = $stats->{total_status};
   $total_media = $stats->{total_media};
   $favorites = $stats->{favorites};
   print "following $following followers $followers  total_status $total_status  total_media $total_media  favorites $favorites  \n";	


Collect the stats of the current account.
   
=head2 dispatch
 Internal function         
                  
=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html
=cut
