#!raku

use API::Discord;
use Myisha::Reputation::Schema;
use Red:ver<0.1.24>:api<2>;
use Redis::Async;

my $discord-token = %*ENV<MYISHA_DISCORD_TOKEN> || die;

my $GLOBAL::RED-DB = database "Pg", :host<localhost>, :database<zoe>, :user<zoe>, :password<password>;
my $redis = Redis::Async.new('127.0.0.1:6379', timeout => 0);

Reputation.^create-table: :if-not-exists;

sub MAIN($discord-token) {
    my $discord = API::Discord.new(:token($discord-token));

    $discord.connect;
    await $discord.ready;

    react {
        whenever $discord.messages -> $message {
            given $message.content {
                when $message.content ~~ / '<@' '!'? <(\d+)> '>++' / {
                    my $guild = $message.channel.guild;
                    my $reputee-id = $/.Int; 
                    my $reputee-user = $discord.get-user($reputee-id);
                    my $reputee = $guild.get-member($reputee-user);
                    my $reputator-id = $message.author-id;
                    my $reputator-user = $discord.get-user($reputator-id);
                    my $reputator = $guild.get-member($reputator-user);

                    my $redis-key = $reputator-id ~ "-" ~ $reputee-id;

                    if $reputator-id != $reputee-id {
                        if $redis.exists($redis-key) and $redis.get($redis-key) ne $guild.id {
                            $redis.setex($redis-key, 86400, $guild.id);
                            .elems ?? .map(*.reputation += 1).save !! .create: :1reputation with Reputation.^all.grep({ .guild-id == $guild.id && .user-id == $reputee-id });
                            $message.channel.send-message(embed => { author => { icon_url => "https://cdn.discordapp.com/avatars/{$reputee-user.id}/{$reputee-user.avatar-hash}.png", name => "{$reputee.display-name}++" }, color => 7324194, description => "{$reputator.display-name} has given {$reputee.display-name} a reputation point!"});
                        }
                    }
                }
            }
        }
    }
}
