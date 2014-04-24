###
# Smoothed Markov Model implementation in CoffeeScript
#
# Copyright (c) 2014 Anthony Bau.
# MIT License.
###

exports = {}

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

  result = new SmoothedMarkovModel front.order, front.alphabet, true

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

if window? then window.classyfi = exports
else if module? then module.exports = exports
