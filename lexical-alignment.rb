#!/usr/bin/env ruby

require 'pp'
require 'rdf/raptor'
require 'linkeddata'
require 'rdf'
require 'rdf/turtle'
require 'rdf-lemon'
require 'nokogiri'
require 'pry'
require 'triez'

 RU_UPPERCASE = [
  "\u0410", "\u0411", "\u0412", "\u0413", "\u0414", "\u0415", "\u0416", "\u0417",
  "\u0418", "\u0419", "\u041A", "\u041B", "\u041C", "\u041D", "\u041E", "\u041F",
  "\u0420", "\u0421", "\u0422", "\u0423", "\u0424", "\u0425", "\u0426", "\u0427",
  "\u0428", "\u0429", "\u042A", "\u042B", "\u042C", "\u042D", "\u042E", "\u042F",
  "\u0401" # Ё
 ].join

RU_LOWERCASE = [
  "\u0430", "\u0431", "\u0432", "\u0433", "\u0434", "\u0435", "\u0436", "\u0437",
  "\u0438", "\u0439", "\u043A", "\u043B", "\u043C", "\u043D", "\u043E", "\u043F",
  "\u0440", "\u0441", "\u0442", "\u0443", "\u0444", "\u0445", "\u0446", "\u0447",
  "\u0448", "\u0449", "\u044A", "\u044B", "\u044C", "\u044D", "\u044E", "\u044F",
  "\u0451" # Ё
].join

def normalize(o)
  o.to_s.tap(&:strip!).tap(&:downcase!).
    tap { |s| s.tr!(RU_UPPERCASE, RU_LOWERCASE) }
end

lexicon1, lexicon2 = Triez.new, Triez.new

i = 0

RDF::Reader.open(ARGV[0] || 'unldc.ttl') do |reader|
  reader.each_statement do |_, p, o|
    lexicon1 << normalize(o) if p == RDF::Lemon.writtenRep
    p i if (i += 1) % 500 == 0
  end
end

i = 0

RDF::Reader.open(ARGV[1] || 'yarn.ttl') do |reader|
  reader.each_statement do |_, p, o|
    lexicon2 << normalize(o) if p == RDF::Lemon.writtenRep
    p i if (i += 1) % 500 == 0
  end
end

a1 = []; lexicon1.each { |k, _| a1 << k }
a2 = []; lexicon2.each { |k, _| a2 << k }

puts 'The intersection is %d lexical entries.' % (a1 & a2).length
