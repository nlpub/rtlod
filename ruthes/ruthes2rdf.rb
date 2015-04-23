#!/usr/bin/env ruby

require 'rdf/raptor'
require 'linkeddata'
require 'rdf'
require 'rdf/turtle'
require 'rdf-lemon'
require 'nokogiri'
require 'pry'

uri = RDF::URI('http://labinform.ru/pub/ruthes/')

entry_uri      = proc { |id| uri + 'te/%d.htm' % id }
lemma_uri      = proc { |entry_id| uri + 'te/%d.htm#lemma' % entry_id }
sense_uri      = proc { |concept_id, entry_id| uri + 'te/%d.htm#c%d' % [entry_id, concept_id] }
concept_uri    = proc { |id| uri + 'c/%d.htm' % id }
definition_uri = proc { |concept_id| uri + 'c/%d.htm#gloss' % concept_id }

graph = RDF::Graph.new

graph << [uri, RDF.type, RDF::Lemon.Lexicon]
graph << [uri, RDF.type, RDF::OWL.Ontology]
graph << [uri, RDF::RDFS.label, 'RuThes-lite']
graph << [uri, RDF::DC.title, 'RuThes-lite']
graph << [uri, RDF::DC.date, Date.today.iso8601]

File.open('text_entry.xml') do |f|
  doc = Nokogiri::XML(f)

  i = 0

  doc.xpath('/entries/entry').each do |entry|
    subject = entry_uri[entry[:id]]

    graph << [subject, RDF.type, RDF::Lemon.LexicalEntry]
    graph << [subject, RDF::Lemon.entry, uri]

    unless (name = entry.children.find { |c| c.name == 'name' }).text.empty?
      text = RDF::Literal.new(name.text, :language => :ru)
      graph << [subject, RDF::RDFS.label, text]
    end

    unless (lemma = entry.children.find { |c| c.name == 'lemma' }).text.empty?
      subject_lemma = lemma_uri[entry[:id]]

      text = RDF::Literal.new(lemma.text, :language => :ru)
      graph << [subject_lemma, RDF.type, RDF::Lemon.Form]
      graph << [subject_lemma, RDF::RDFS.label, text]
      graph << [subject_lemma, RDF::Lemon.writtenRep, text]
      graph << [subject, RDF::Lemon.canonicalForm, subject_lemma]
    end

    p i if (i += 1) % 500 == 0
  end
end

File.open('synonyms.xml') do |f|
  doc = Nokogiri::XML(f)

  i = 0

  doc.xpath('/synonyms/entry_rel').each do |relation|
    subject = sense_uri[relation[:concept_id], relation[:entry_id]]

    concept = concept_uri[relation[:concept_id]]
    entry = entry_uri[relation[:entry_id]]

    graph << [subject, RDF.type, RDF::Lemon.LexicalSense]

    graph << [entry, RDF::Lemon.sense, subject]
    graph << [subject, RDF::Lemon.isSenseOf, entry]
    graph << [subject, RDF::Lemon.reference, concept]
    graph << [concept, RDF::Lemon.isReferenceOf, subject]

    p i if (i += 1) % 500 == 0
    # break if i == 500
  end
end

File.open('concepts.xml') do |f|
  doc = Nokogiri::XML(f)

  i = 0

  doc.xpath('/concepts/concept').each do |concept|
    subject = concept_uri[concept[:id]]

    graph << [subject, RDF.type, RDF::SKOS.Concept]

    concept.xpath('./name').each do |name|
      next if name.text.empty?
      text = RDF::Literal.new(name.text, :language => :ru)
      graph << [subject, RDF::RDFS.label, text]
    end

    concept.xpath('./gloss').each do |gloss|
      next if gloss.text.empty?
      text = RDF::Literal.new(gloss.text, :language => :ru)

      subject_definition = definition_uri[concept[:id]]

      graph << [subject_definition, RDF.type, RDF::Lemon.SenseDefinition]
      graph << [subject_definition, RDF::RDFS.label, text]
      graph << [subject_definition, RDF::Lemon.value, text]

      # RDF::Query.new { pattern [:sense, RDF::Lemon.reference, subject] }.execute(graph) do |solution|
      #   subject_sense = solution[:sense]
      #   graph << [subject_sense, RDF::Lemon.definition, subject_definition]
      # end
    end

    p i if (i += 1) % 500 == 0
  end
end

File.open('relations.xml') do |f|
  doc = Nokogiri::XML(f)

  i = 0

  doc.xpath('/relations/rel').each do |relation|
    concept1 = concept_uri[relation[:from]]
    concept2 = concept_uri[relation[:to]]

    case relation[:name]
    when 'ВЫШЕ'.freeze then
      graph << [concept1, RDF::SKOS.broader, concept2]
    when 'НИЖЕ'.freeze then
      graph << [concept1, RDF::SKOS.narrower, concept2]
    when 'ЧАСТЬ'.freeze then
      graph << [concept1, RDF::LexInfo.holonymTerm, concept2]
    when 'ЦЕЛОЕ'.freeze then
      graph << [concept1, RDF::LexInfo.meronymTerm, concept2]
    when 'АСЦ1'.freeze then
      graph << [concept1, RDF::Lemon.subsense, concept2]
    when 'АСЦ2'.freeze then
      graph << [concept2, RDF::Lemon.subsense, concept1]
    when 'АСЦ'.freeze then
      graph << [concept1, RDF::SKOS.related, concept2]
      graph << [concept2, RDF::SKOS.related, concept1]
    end

    p i if (i += 1) % 500 == 0
  end
end

RDF::Writer.open('ruthes-lite.n3') do |writer|
  writer.prefix! :rdf, RDF::to_uri
  writer.prefix! :rdfs, RDF::RDFS.to_uri
  writer.prefix! :owl, RDF::OWL.to_uri
  writer.prefix! :dc, RDF::DC::to_uri
  writer.prefix! :skos, RDF::SKOS.to_uri
  writer.prefix! :lemon, RDF::Lemon.to_uri
  writer.prefix! :lexinfo, RDF::LexInfo.to_uri

  writer << graph
end
