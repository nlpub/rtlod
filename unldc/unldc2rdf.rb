#!/usr/bin/env ruby

# http://www-clips.imag.fr/geta/User/viacheslav.dikonov/docs/UNL-Dictionary-presentation.pdf

require 'csv'
require 'digest/md5'
require 'rdf/raptor'
require 'rdf'
require 'rdf/turtle'
require 'rdf/n3'
require 'rdf-lemon'
require 'nokogiri'
require 'pry'

uri = RDF::URI('http://unl.ru/')

entry_uri      = proc { |uw| uri + '#%s' % Digest::MD5.hexdigest(uw) }
lemma_uri      = proc { |uw| uri + '#%s_lemma' % Digest::MD5.hexdigest(uw) }
sense_uri      = proc { |uw| uri + '#%s_sense' % Digest::MD5.hexdigest(uw) }
definition_uri = proc { |uws| uri + '#concept_%s_gloss' % Digest::MD5.hexdigest(uws) }
concept_uri    = proc { |uws| uri + '#concept_%s' % Digest::MD5.hexdigest(uws) }

def parse(uw)
  return unless md = uw.match(/^(.+?)\((.+?)\)$/)
  [md[1], md[2].split(',')]
end

graph = RDF::Graph.new

graph << [uri, RDF.type, RDF::Lemon.Lexicon]
graph << [uri, RDF.type, RDF::OWL.Ontology]
graph << [uri, RDF::RDFS.label, 'Universal Dictionary of Concepts']
graph << [uri, RDF::DC.title, 'Universal Dictionary of Concepts']
graph << [uri, RDF::DC.date, Date.today.iso8601]

i = 0

CSV.foreach('dict-nl-rus.csv', col_sep: "\t") do |lemma, _, uw, gloss, _, msd, _|
  next unless lemma = lemma[/[А-Яа-яЁё ]+/u]

  subject, subject_lemma = entry_uri[uw], lemma_uri[uw]

  text = RDF::Literal.new(lemma, :language => :ru)

  graph << [subject, RDF.type, RDF::Lemon.LexicalEntry]
  graph << [subject, RDF::Lemon.entry, uri]
  graph << [subject, RDF::RDFS.label, text]

  pos = case msd[/\w+/]
  when 'n' then RDF::LexInfo.noun
  when 'a' then RDF::LexInfo.adjective
  when 'adv' then RDF::LexInfo.adverb
  when 'v' then RDF::LexInfo.verb
  when 'num' then RDF::LexInfo.numeral
  when 'part' then RDF::LexInfo.particle
  when 'conj' then RDF::LexInfo.conjunction
  when 'intj' then RDF::LexInfo.interjection
  when 'pr' then RDF::LexInfo.preposition
  else
  end

  graph << [subject_lemma, RDF.type, RDF::Lemon.Form]
  graph << [subject_lemma, RDF::RDFS.label, text]
  graph << [subject_lemma, RDF::Lemon.writtenRep, text]
  graph << [subject, RDF::Lemon.canonicalForm, subject_lemma]
  graph << [subject, RDF::LexInfo.partOfSpeech, pos] if pos

  p i if (i += 1) % 500 == 0
  # break if (i += 1) == 1000
end

i = 0

CSV.foreach('russian-synsets.csv', skip_lines: /^ *#/, col_sep: "\t", quote_char: "\x00") do |words, gloss, uws|
  next unless uws and subject = concept_uri[uws]

  text = RDF::Literal.new(words, :language => :ru)

  graph << [subject, RDF.type, RDF::SKOS.Concept]
  graph << [subject, RDF::RDFS.label, text]

  subject_definition = definition_uri[uws]

  if gloss and !gloss.empty?
    graph << [subject_definition, RDF.type, RDF::Lemon.SenseDefinition]
    graph << [subject_definition, RDF::RDFS.label, gloss]
    graph << [subject_definition, RDF::Lemon.value, gloss]
  end

  uws.split('+').each do |uw|
    subject_word, subject_sense = entry_uri[uw], sense_uri[uw]

    graph << [subject_sense, RDF.type, RDF::Lemon.LexicalSense]
    graph << [subject_sense, RDF::RDFS.label, uw]
    graph << [subject_sense, RDF::Lemon.reference, subject]
    graph << [subject, RDF::Lemon.isReferenceOf, subject_sense]
    graph << [subject_word, RDF::Lemon.sense, subject_sense]
    graph << [subject_sense, RDF::Lemon.isSenseOf, subject_word]
    graph << [subject_sense, RDF::Lemon.definition, subject_definition] if gloss and !gloss.empty?
  end

  p i if (i += 1) % 500 == 0
  # break if (i += 1) == 1000
end

RDF::Writer.open('unldc.n3') do |writer|
  writer.prefix! :rdf, RDF::to_uri
  writer.prefix! :rdfs, RDF::RDFS.to_uri
  writer.prefix! :owl, RDF::OWL.to_uri
  writer.prefix! :dc, RDF::DC::to_uri
  writer.prefix! :skos, RDF::SKOS.to_uri
  writer.prefix! :lemon, RDF::Lemon.to_uri
  writer.prefix! :lexinfo, RDF::LexInfo.to_uri

  writer << graph
end
