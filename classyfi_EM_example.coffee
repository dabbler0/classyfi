###
# Example 1: Charles Dickens' Great Expectations vs. Jane Austen's Pride and Prejudice.
###

fs = require 'fs'
readline = require 'readline'
classyfi = require './classyfi.coffee'

order = 1

austen = fs.readFileSync('data/latin.txt').toString()
dickens = fs.readFileSync('data/english.txt').toString()

tokenize = (string) ->
  #string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, ' ').replace(/\ +/g, ' ').split ' '
  string.toLowerCase().replace(/[^\w \.]/g, '').split('')

console.log 'loaded'
austen = austen.split('.').map((paragraph) -> tokenize paragraph).filter((x) -> x.length > 10).map (doc) -> {doc, tag: 0}
dickens = dickens.split('.').map((paragraph) -> tokenize paragraph).filter((x) -> x.length > 10).map (doc) -> {doc, tag: 1}
console.log 'tokenized'

mixed = austen.concat(dickens).sort((a, b) -> Math.round Math.random() - 1)

trueTags = mixed.map (x) -> x.tag
mixedCorpus = mixed.map (x) -> x.doc
console.log 'mixed.'

#bigMixed = mixedCorpus[0...8000].reduce((a, b) -> a.concat(b))
alphabet = 'abcdefghijklmnopqrstuvwxyz. '.split('')
#alphabet = classyfi.getMostCommonTokens bigMixed, 6000
alphabet.push '*'

console.log alphabet.length

console.log 'determined alphabet.'

mixedCorpus = mixedCorpus.map (doc) -> doc.map (token) -> if token in alphabet then token else '*'

console.log mixedCorpus.length

console.log 'stripped unknown tokens'

console.log mixedCorpus[0]

classyfi.estimationMaximization mixedCorpus, 1, alphabet, 2, 0.01, (tags) ->
  console.log 'Accuracy:', tags.map((x, i) -> if x is trueTags[i] then 1 else 0).reduce((a, b) -> a + b) / tags.length
