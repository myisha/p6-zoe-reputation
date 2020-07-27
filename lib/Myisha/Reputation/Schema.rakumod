unit package Myisha::Reputation::Schema;
use Red:api<2>;

model Reputation is table<reputation> is rw is export {
    has Int $.guild-id          is column{ :id, :type<bigint> }
    has Int $.user-id           is column{ :id, :type<bigint> }
    has Int $.reputation        is column;
    has DateTime $.last-updated is column{ :type<timestamptz> } = DateTime.now;
    method !update-time($_) is before-update { .last-updated = DateTime.now }

    method leaderboard {}
    method check {}
    method purge {}
}
