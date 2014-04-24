HashTable = require 'hashtable'

exports.Estmator = class Estimator
  constructor: ->

  feed: (tokens) ->
  
  estimate: (tokens) -> 0

exports.MarkovModel = class MarkovModel extends Estimator
  constructor: (@order, @alphabet, @count = 0, suppressInit = false) ->
    unless @order is 0
      @children = new HashTable()
      
      unless suppressInit
        for token in @alphabet
          @children.put token, new MarkovModel @order - 1, @alphabet
  
  increment: (vector) ->
    @count += 1
    unless @order is 0
      @children.get(vector[0]).increment vector[1..]

  smoothHO: (other) ->
    unless @order is 0
      bucketCounts = {}
      bucketSizes = {}

      for token in @alphabet
        tokenCount = @children.get(token).count

        bucketCounts[tokenCount] = 0

        bucketSizes[tokenCount] ?= 0
        bucketSizes[tokenCount] += 1

      for token in @alphabet
        bucketCounts[@children.get(token).count] += other.children.get(token).count
      
      smoothedCounts = {}

      for token in @alphabet
        smoothedCounts[token] = bucketCounts[@children.get(token).count] / bucketSizes[@children.get(token).count]

      result = new MarkovModel @order, @alphabet, @count, true

      newChildren = new HashTable()

      for token in @alphabet
        newChildren.put token, @children.get(token).smoothHO other.children.get(token)
        newChildren.get(token).count = smoothedCounts[token]

      result.children = newChildren

      return result

    else
      return new MarkovModel @order, @alphabet, @count
  
  add: (other) ->
    result = new MarkovModel @order, @alphabet, @count + other.count, true
    
    unless @order is 0
      for token in @alphabet
        result.children.put token, @children.get(token).add other.children.get(token)

    return result
  
  normalize: ->
    unless @order is 0
      total = 0

      for token in @alphabet
        total += @children.get(token).count

      for token in @alphabet
        @children.get(token).count /= total
        @children.get(token).normalize()

  clearCache_: ->
    @normalize()

  feed: (tokens) ->
    for i in [@order...tokens.length]
      @increment tokens[i - @order..i]
  
  getProbability: (ngram, i = 0) ->
    if @order is 0 then 0
    else Math.log(@children.get(ngram[i]).count) + @children.get(ngram[i]).getProbability ngram, i + 1

  estimate: (tokens) ->
    if @mustClearCache_ then @clearCache_()
    @mustClearCache_ = false

    probability = 0
    for i in [@order...tokens.length]
      ngram = tokens[i - @order..i]
      probability += @getProbability ngram

    return probability
  
  getRandomToken: (startVector) ->
    obj = this
    for i in [0...@order - 1]
      obj = obj.children.get(startVector[i])

    point = 0; barrier = Math.random()
    for token in @alphabet
      point += obj.children.get(token).count
      if point > barrier then return token

    return @alphabet[@alphabet.length - 1]
  
  generateRandom: (n) ->
    startVector = (@alphabet[Math.floor Math.random() * @alphabet.length] for [0...@order - 1])

    str = ''
    
    for [1..n]
      char = @getRandomToken startVector
      startVector.shift()
      startVector.push char

      str += char + ' '

    return str

exports.SmoothedMarkovModel = class SmoothedMarkovModel extends Estimator
  constructor: (@order, @alphabet, @count = 0) ->
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

order = 2

austen = fs.readFileSync 'austen.txt'
dickens = fs.readFileSync 'dickens.txt'

tokenize = (string) ->
  string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split ' '

austen = tokenize austen.toString()
dickens = tokenize dickens.toString()

console.log 'Tokenized.'

alphabet = getMostCommonTokens austen.concat(dickens), 1000
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

###
iface = readline.createInterface
  input: process.stdin
  output: process.stdout

iface.on 'line', (line) ->
  line = filter tokenize(line), alphabet
  console.log 'DICKENS:', dEstimate = dickensModel.estimate line
  console.log 'AUSTEN:', aEstimate = austenModel.estimate line
  
  console.log if aEstimate > dEstimate then 'AUSTEN' else 'DICKENS'
  iface.prompt()

iface.prompt()
###

dickensTest = fs.readFileSync 'dickens_test.txt'
dickensTest = dickensTest.toString().split '\n'

surprise = 0
len = 0

console.log 'Loaded test data.'

right = 0
wrong = 0
for line in dickensTest
  line = filter tokenize(line), alphabet
  unless line.length < 3
    d = dickensModel.estimate line
    a = austenModel.estimate line

    if d > a then right += 1
    else wrong += 1

console.log 'DICKENS ACCURACY:', right / (right + wrong)
len += (right + wrong)

austenTest = fs.readFileSync 'austen_test.txt'
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

console.log 'AUSTEN ACCURACY:', right / (right + wrong)
len += (right + wrong)
