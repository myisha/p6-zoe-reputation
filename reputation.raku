#!raku

use API::Discord;
use API::Discord::Permissions;
use Myisha::Reputation::Schema;
use Red:api<2>;
use Redis::Async;

my $GLOBAL::RED-DB = database "Pg", :host<localhost>, :database<zoe>, :user<zoe>, :password<password>;
my $redis = Redis::Async.new('127.0.0.1:6379', timeout => 0);
my $*RED-DEBUG = True;

Reputation.^create-table: :if-not-exists;

sub MAIN($discord-token) {
    my $discord = API::Discord.new(:token($discord-token));

    $discord.connect;
    await $discord.ready;

    react {
        whenever $discord.messages -> $message {
            given $message.content {
                when $message.content ~~ /^ '<@' '!'? <(\d+)> '>' \s* '++' $/ {
                    my $guild = $message.channel.guild;
                    my $reputee = $guild.get-member($discord.get-user($/.Int));
                    my $reputator = $guild.get-member($message.author);

                    my $redis-key = $guild.id ~ "-" ~ $reputator.user.id ~ "-" ~ $reputee.user.id;

                    if $reputator.user.id != $reputee.user.id and not $redis.exists($redis-key) {
                        $redis.setex($redis-key, 86400, DateTime.now);
                        my $reputation = Reputation.^all.grep({ .guild-id == $guild.id && .user-id == $reputee.user.id });

                        if $reputation.elems {
                            $reputation.map(*.reputation += 1).save
                        }
                        else {
                            $reputation.create: :1reputation
                        }

                        $message.channel.send-message(
                            embed => {
                                author => {
                                    icon_url => $reputee.user.avatar-url,
                                    name => "{$reputee.display-name}++"
                                },
                                color => 7324194,
                                description => "{$reputator.display-name} has given {$reputee.display-name} a reputation point!"
                            }
                        );
                    } elsif $redis.exists($redis-key) {
                        my ($secs, $mins, $hours) = $redis.ttl($redis-key).polymod(60, 60, 24);
                        $message.channel.send-message(
                            embed => {
                                author => {
                                    icon_url => $reputee.user.avatar-url,
                                    name => "You can't do that yet!"
                                },
                                color => 14488339,
                                description => "You can give {$reputee.display-name} reputation in {$hours} hours, {$mins} minutes and {$secs} seconds."
                            }
                        );
                    }
                }
                when $message.content ~~ m/^ "+rep" \s* ["<@" "!"? (\d+) ">"]? $/ {
                    my $guild = $message.channel.guild;
                    my $guild-id = $message.channel.guild.id;
                    my $user-id = ($0 ?? $0.Int !! $message.author.id);
                    my $user = $guild.get-member($discord.get-user($user-id));

                    my $rep-query = Reputation.check: :guild-id($guild-id), :user-id($user-id);
                    my $reputation = $rep-query ?? $rep-query.reputation !! 0;

                    $message.channel.send-message(
                        embed => {
                            author => {
                                icon_url => $user.user.avatar-url,
                                name => "{$user.display-name}"
                            },
                            color => 7324194,
                            description => "{$user.display-name} has {$reputation} reputation points."
                        }
                    );
                }
                when $message.content ~~ m/^ "+rep purge" \s "<@" "!"? <(\d+)> ">" $/ {
                    my $guild = $message.channel.guild;
                    my $user = $guild.get-member($discord.get-user($/.Int));

                    if $guild.get-member($message.author).has-any-permission([ADMINISTRATOR]) {
                        my $reputation = Reputation.check: :guild-id($guild.id), :user-id($user.user.id);
                        $reputation.purge;

                        $message.channel.send-message(
                            embed => {
                                author => {
                                    icon_url => $user.user.avatar-url,
                                    name => "{$user.display-name}"
                                },
                                color => 14991639,
                                description => "{$guild.get-member($message.author).display-name} reset {$user.display-name}'s reputation."
                            }
                        );
                    } else {
                        $message.channel.send-message(
                            embed => {
                                author => {
                                    icon_url => $user.user.avatar-url,
                                    name => "Exception"
                                },
                                color => 14488339,
                                description => "You don't have permission to reset {$user.display-name}'s reputation."                      
                            }
                        );
                    }
                }
            }
        }
    }
}
