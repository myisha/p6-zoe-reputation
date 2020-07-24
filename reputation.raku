#!raku

use API::Discord;
use Myisha::Reputation::Schema;
use Red:ver<0.1.24>:api<2>;
use Redis::Async;


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
                when $message.content ~~ / '<@' '!'? <(\d+)> '>' \s* '++' / {
                    my $guild = $message.channel.guild;
                    my $reputee-id = $/.Int; 
                    my $reputee-user = $discord.get-user($reputee-id);
                    my $reputee = $guild.get-member($reputee-user);
                    my $reputator-id = $message.author-id;
                    my $reputator-user = $discord.get-user($reputator-id);
                    my $reputator = $guild.get-member($reputator-user);

                    my $redis-key = $guild.id ~ "-" ~ $reputator-id;

                    if $reputator-id != $reputee-id and not $redis.exists($redis-key) and $redis.get($redis-key) ne $reputee-id {
                        $redis.setex($redis-key, 86400, $reputee-id);
                        my $reputation = Reputation.^all.grep({ .guild-id == $guild.id && .user-id == $reputee-id });

                        if $reputation.elems {
                            $reputation.map(*.reputation += 1).save
                        }
                        else {
                            $reputation.create: :1reputation
                        }

                        $message.channel.send-message(
                            embed => {
                                author => {
                                    icon_url => $reputee-user.avatar-url,
                                    name => "{$reputee.display-name}++"
                                },
                                color => 7324194,
                                description => "{$reputator.display-name} has given {$reputee.display-name} a reputation point!"
                            }
                        );
                    }
                }
            }
        }
    }
}