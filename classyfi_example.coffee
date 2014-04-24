exports.Estmator = class Estimator
  constructor: ->

  feed: (tokens) ->
  
  estimate: (tokens) -> 0

exports.MarkovModel = class MarkovModel extends Estimator
  constructor: (@order, @alphabet, @count = 0, suppressInit = false) ->
    unless @order is 0
      @children = {}
      
      unless suppressInit
        for token in @alphabet
          @children[token] = new MarkovModel @order - 1, @alphabet
  
  increment: (vector) ->
    @count += 1
    unless @order is 0
      @children[vector[0]].increment vector[1..]

  smoothHO: (other) ->
    unless @order is 0
      bucketCounts = {}
      bucketSizes = {}

      for token in @alphabet
        tokenCount = @children[token].count

        bucketCounts[tokenCount] = 1

        bucketSizes[tokenCount] ?= 0
        bucketSizes[tokenCount] += 1

      for token in @alphabet
        bucketCounts[@children[token].count] += other.children[token].count
      
      smoothedCounts = {}

      for token in @alphabet
        smoothedCounts[token] = bucketCounts[@children[token].count] / bucketSizes[@children[token].count]

      result = new MarkovModel @order, @alphabet, @count, true

      newChildren = {}

      for token in @alphabet
        newChildren[token] = @children[token].smoothHO other.children[token]
        newChildren[token].count = smoothedCounts[token]

      result.children = newChildren

      return result

    else
      return new MarkovModel @order, @alphabet, @count
  
  add: (other) ->
    result = new MarkovModel @order, @alphabet, @count + other.count, true
    
    unless @order is 0
      for token in @alphabet
        result.children[token] = @children[token].add other.children[token]

    return result
  
  normalize: ->
    unless @order is 0
      total = 0

      for token in @alphabet
        total += @children[token].count

      for token in @alphabet
        @children[token].count /= total
        @children[token].normalize()

  clearCache_: ->
    @normalize()

  feed: (tokens) ->
    for i in [@order...tokens.length]
      @increment tokens[i - @order..i]
  
  getProbability: (ngram, i = 0) ->
    if @order is 0 then 0
    else Math.log(@children[ngram[i]].count) + @children[ngram[i]].getProbability ngram, i + 1

  estimate: (tokens) ->
    if @mustClearCache_ then @clearCache_()
    @mustClearCache_ = false

    probability = 0
    for i in [@order...tokens.length]
      ngram = tokens[i - @order..i]
      if @getProbability(ngram) isnt @getProbability(ngram) then console.log 'OOPS: cannot get prob for', ngram
      probability += @getProbability ngram

    return probability
  
  getRandomToken: (startVector) ->
    obj = this
    for i in [0...@order - 1]
      obj = obj.children[startVector[i]]

    point = 0; barrier = Math.random()
    for token in @alphabet
      point += obj.children[token].count
      if point > barrier then return token

    return @alphabet[@alphabet.length - 1]
  
  generateRandom: (n) ->
    startVector = (@alphabet[Math.floor Math.random() * @alphabet.length] for [0...@order - 1])

    str = ''
    
    for [1..n]
      char = @getRandomToken startVector
      startVector.shift()
      startVector.push char

      str += char# + ' '

    return str
  
  serialize: ->
    unless @order is 0
      dict = {}
      dict[token] = @children[token].serialize() for token in @alphabet
      return {
        count: @count
        children: dict
      }

    else
      return @count


MarkovModel.fromSerialized = (s, alphabet = null) ->
    if typeof s is 'number' or s instanceof Number
      return new MarkovModel 0, alphabet, s

    else
      if not alphabet?
        alphabet = []
        alphabet.push token for token of s.children
      
      childrenDict = {}

      for token in alphabet
        childrenDict[token] = MarkovModel.fromSerialized s.children[token]

      result = new MarkovModel childrenDict[alphabet[0]].order + 1, alphabet, s.count, true

      result.children = childrenDict
      
      return result

exports.SmoothedMarkovModel = class SmoothedMarkovModel extends Estimator
  constructor: (@order, @alphabet, suppressInit = false) ->
    unless suppressInit
      @front = new MarkovModel @order, @alphabet
      @back = new MarkovModel @order, @alphabet

      @smoothed = null
    @mustClearCache_ = false

  feed: (tokens) ->
    if @front.count < @back.count
      @front.feed tokens
    else
      @back.feed tokens

    @mustClearCache_ = true
  
  clearCache_: ->
    @smoothed = @front.smoothHO(@back).add(@back.smoothHO(@front))
    @smoothed.normalize()

  estimate: (tokens) ->
    if @mustClearCache_ then @clearCache_()
    @mustClearCache_ = false
    @smoothed.estimate tokens

  serialize: ->
    {
      front: @front.serialize()
      back: @back.serialize()
      smoothed: @smoothed.serialize()
    }

SmoothedMarkovModel.fromSerialized = (s) ->
  front = MarkovModel.fromSerialized s.front
  back = MarkovModel.fromSerialized s.back
  smoothed = MarkovModel.fromSerialized s.smoothed

  result = new MarkovModel front.order, front.alphabet, true

  result.front = front; result.back = back; result.smoothed = smoothed

  return result

exports.Category = class Category
  constructor: (@estimator) ->
    @tokenCount = 0
  
  feed: (tokens) ->
    @estimator.feed tokens
    @tokenCount += tokens.length

  estimate: (tokens) ->
    @estimator.estimate tokens

exports.Classifier = class Classifier
  constructor: (@categories) ->
  
  classify: (tokens) ->
    total = 0
    total += category.tokenCount for category in @categories

    categoryProbabilities = []
    for category, i in @categories
      categoryProbabilities[i] = Math.log(category.tokenCount) + category.estimate tokens

    return categoryProbabilities

exports.getMostCommonTokens = getMostCommonTokens = (array, n) ->
  counts = {}
  for token in array
    counts[token] ?= 0
    counts[token] += 1

  best = []
  for token, count of counts
    if best.length is 0 then best.push {
      count: count
      token: token
    }
    else for record, i in best
      if count > record.count
        best.splice i, 0, {
          count: count
          token: token
        }
        if best.length > n then best.pop()
        break

  return (record.token for record in best)

###
# TESTS
###

###
# Example 1: Charles Dickens' Great Expectations vs. Jane Austen's Pride and Prejudice.
###

fs = require 'fs'
readline = require 'readline'

order = 1

austen = fs.readFileSync 'data/austen.txt'
dickens = fs.readFileSync 'data/dickens.txt'

tokenize = (string) ->
  string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split ' '
  # Please note that the above * / must be turned into a *\/ when uncommented

austen = tokenize austen.toString()
dickens = tokenize dickens.toString()

console.log 'Tokenized.'

alphabet = getMostCommonTokens austen.concat(dickens), 6000
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

austenModel = new SmoothedMarkovModel order, alphabet
dickensModel = new SmoothedMarkovModel order, alphabet

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

console.log 'Smoothed.'

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

latinModel = new SmoothedMarkovModel order, alphabet
englishModel = new SmoothedMarkovModel order, alphabet

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
