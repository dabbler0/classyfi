###
# Example 1: Charles Dickens' Great Expectations vs. Jane Austen's Pride and Prejudice.
###

fs = require 'fs'
readline = require 'readline'
classyfi = require 'classyfi'

order = 1

austen = fs.readFileSync 'data/austen.txt'
dickens = fs.readFileSync 'data/dickens.txt'

tokenize = (string) ->
  string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split ' '
  # Please note that the above * / must be turned into a *\/ when uncommented

austen = tokenize austen.toString()
dickens = tokenize dickens.toString()

console.log 'Tokenized.'

alphabet = classyfi.getMostCommonTokens austen.concat(dickens), 6000
alphabet.push '*'

console.log 'Obtained alphabet.'

filter = (corpus, alphabet) ->
  result = []
  for token in corpus
    if token in alphabet then result.push token
    else result.push '*'
  return result

austen = filter austen, alphabet
dickens = filter dickens, alphabet

console.log 'Filtered tokens for alphabet.'

console.log 'Initializing...'

austenModel = new classyfi.SmoothedMarkovModel order, alphabet
dickensModel = new classyfi.SmoothedMarkovModel order, alphabet

console.log 'Inititialized.'

addFrontBack = (corpus, model) ->
  front = corpus[0..Math.floor corpus.length / 2]
  back = corpus[Math.floor(corpus.length / 2)...corpus.length]
  
  console.log 'Front...'
  model.feed front
  console.log 'Back...'
  model.feed back

console.log 'Feeding dickens...'
addFrontBack dickens, dickensModel
console.log 'Feeding austen...'
addFrontBack austen, austenModel

console.log 'Trained.'

dickensModel.clearCache_(); austenModel.clearCache_()

console.log 'classyfi.Smoothed.'

console.log 'DICKENS RANDOM:', dickensModel.smoothed.generateRandom(100)
console.log 'AUSTEN RANDOM:', austenModel.smoothed.generateRandom(100)

dickensTest = fs.readFileSync 'data/dickens_test.txt'
dickensTest = dickensTest.toString().split '\n'

surprise = 0
len = 0

console.log 'Loaded test data.'

tright = total = 0
right = 0
wrong = 0
for line in dickensTest
  line = filter tokenize(line), alphabet
  unless line.length < 3
    d = dickensModel.estimate line
    a = austenModel.estimate line

    if d > a then right += 1
    else wrong += 1

tright += right; total += right + wrong
console.log 'DICKENS ACCURACY:', right / (right + wrong)
len += (right + wrong)

austenTest = fs.readFileSync 'data/austen_test.txt'
austenTest = austenTest.toString().split '\n'

console.log 'Loaded test data.'

right = 0
wrong = 0
for line in austenTest
  line = filter tokenize(line), alphabet
  unless line.length < 3
    a = austenModel.estimate line
    d = dickensModel.estimate line

    if a > d then right += 1
    else wrong += 1

tright += right; total += right + wrong
console.log 'AUSTEN ACCURACY:', right / (right + wrong)
console.log 'TOTAL ACCURACY:', tright / total

fs.writeFile 'data/dickens_model.json', JSON.stringify dickensModel.serialize()
fs.writeFile 'data/austen_model.json', JSON.stringify austenModel.serialize()

# DICKENS: 69% accuracy
# AUSTEN:  80% accruacy

###
# Example 2: Latin vs. English
###
###
alphabet = 'abcdefghijklmnopqrstuvwxyz. '.split ''
order = 3

latinModel = new classyfi.SmoothedMarkovModel order, alphabet
englishModel = new classyfi.SmoothedMarkovModel order, alphabet

latin = fs.readFileSync 'data/latin.txt'
english = fs.readFileSync 'data/english.txt'

tokenize = (text) ->
  text.toLowerCase().replace(/[^a-z \.]/g, '').split ''

addFrontBack = (corpus, model) ->
  front = corpus[0..Math.floor corpus.length / 2]
  back = corpus[Math.floor(corpus.length / 2)...corpus.length]
  
  console.log 'Front...'
  model.feed front
  console.log 'Back...'
  model.feed back

latin = tokenize latin.toString()
english = tokenize english.toString()

addFrontBack latin, latinModel
addFrontBack english, englishModel

latinModel.clearCache_(); englishModel.clearCache_()

console.log latinModel.smoothed.generateRandom 1000
console.log englishModel.smoothed.generateRandom 1000

latinTest = fs.readFileSync 'data/latin_test.txt'
englishTest = fs.readFileSync 'dta/english_test.txt'

latinTest = latinTest.toString().split '\n'
englishTest = englishTest.toString().split '\n'

tright = 0; total = 0
right = 0; wrong = 0
for line in latinTest
  line = tokenize line

  unless line.length < 4
    l = latinModel.estimate line
    e = englishModel.estimate line

    if l > e then right += 1
    else wrong += 1

console.log 'LATIN ACCURACY:', right / (right + wrong)
tright += right
total += right + wrong

right = 0; wrong = 0
for line in englishTest
  line = tokenize line

  unless line.length < 4
    l = latinModel.estimate line
    e = englishModel.estimate line

    if l < e then right += 1
    else wrong += 1

tright += right; total += right + wrong
console.log 'ENGLISH ACCURACY:', right / (right + wrong)

console.log 'OVERALL ACCURACY:', tright / total

fs.writeFile 'data/latin_model.json', JSON.stringify latinModel.serialize()
fs.writeFile 'data/english_model.json', JSON.stringify englishModel.serialize()
###

###
# Example 2 extension: interactive console
###
###
iface = readline.createInterface
  input: process.stdin
  output: process.stdout

iface.on 'line', (line) ->
  line = tokenize(line)
  console.log 'ENGLISH:', eEstimate = englishModel.estimate line
  console.log 'LATIN:', lEstimate = latinModel.estimate line
  
  console.log if lEstimate > eEstimate then 'LATIN' else 'ENGLISH'
  iface.prompt()

iface.prompt()
###
