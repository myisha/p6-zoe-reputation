unit package Myisha::Reputation::Schema;
use Red:ver<0.1.19>:api<2>;

our $*RED-DB = database "Pg", :host<localhost>, :database<example>, :user<example>, :password<password>;

model Reputation is table<reputation> is rw is export {
    has Int $.guild-id          is id;
    has Int $.user-id           is id;
    has Int $.reputation        is column;
    has DateTime $.last-updated is column{ :type<timestamptz> }
}
