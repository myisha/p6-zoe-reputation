#!raku

use API::Discord;
use Myisha::Reputation::Schema;
use Red:ver<0.1.19>:api<2>;

my $discord-token = %*ENV<MYISHA_DISCORD_TOKEN> || die;
my $*RED-DEBUG = True;

Reputation.^create-table: :if-not-exists;

sub MAIN($discord-token) {
    my $discord = API::Discord.new(:$discord-token);

    $discord.connect;
    await $discord.ready;

    react {
        whenever $discord.messages -> $message { say 'Test' }
    }
}