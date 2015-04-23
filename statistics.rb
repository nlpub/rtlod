#!/usr/bin/env ruby

require 'pp'
require 'rdf/raptor'
require 'linkeddata'
require 'rdf'
require 'rdf/turtle'
require 'rdf-lemon'
require 'nokogiri'
require 'pry'

statistics = Hash.new(0)

i = 0

RDF::Reader.open(ARGV.first || 'yarn.ttl') do |reader|
  reader.each_statement do |s, p, o|
    case p
    when RDF::LexInfo.partOfSpeech then statistics[:postags] += 1; next
    when RDF::SKOS.broader, RDF::SKOS.narrower, RDF::LexInfo.holonymTerm, RDF::LexInfo.meronymTerm, RDF::Lemon.subsense, RDF::SKOS.related then statistics[:relations] += 1; next
    when RDF.type then
    else next
    end

    case o
    when RDF::SKOS.Concept then statistics[:concepts] += 1
    when RDF::Lemon.LexicalEntry then statistics[:entries] += 1
    when RDF::Lemon.LexicalSense then statistics[:senses] += 1
    when RDF::Lemon.SenseDefinition then statistics[:definitions] += 1
    when RDF::Lemon.UsageExample then statistics[:examples] += 1
    end

    pp [i, statistics] if (i += 1) % 500 == 0
  end
end

pp statistics
