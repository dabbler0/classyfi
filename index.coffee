# Latin vs. English

languages = ->
  $('#train').hide()

  $('#input').unbind('input').val ''

  $('#a_tag').text 'Latin'
  $('#b_tag').text 'English'

  $('#a_out').text ''
  $('#b_out').text ''
  $('#result').text ''

  tokenize = (text) ->
    text.toLowerCase().replace(/[^a-z \.]/g, '').split ''

  latinModel = englishModel = null

  $.ajax
    url: 'data/latin_model.json'
    dataType: 'json'
    success: (data) ->
      latinModel = classyfi.SmoothedMarkovModel.fromSerialized data

  $.ajax
    url: 'data/english_model.json'
    dataType: 'json'
    success: (data) ->
      englishModel = classyfi.SmoothedMarkovModel.fromSerialized data

  latinOut = $ '#a_out'
  englishOut = $ '#b_out'
  resultOut = $ '#result'

  $('#input').on 'input', ->
    val = tokenize @value
    if val.length > 15
      l = latinModel.estimate val
      e = englishModel.estimate val

      latinOut.text l
      englishOut.text e
      
      resultOut.text if l > e then 'LATIN' else 'ENGLISH'
    else
      resultOut.text '(insufficient text; minimum length 15 characters)'

writers = ->
  $('#train').hide()

  $('#input').unbind('input').val ''

  $('#a_tag').text 'Jane Austen'
  $('#b_tag').text 'Charles Dickens'

  $('#a_out').text ''
  $('#b_out').text ''
  $('#result').text ''

  tokenize = (string) ->
    string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split ' '

  filter = (corpus, alphabet) ->
    result = []
    for token in corpus
      if token in alphabet then result.push token
      else result.push '*'
    return result

  dickensModel = austenModel = null
  alphabet = []

  $.ajax
    url: 'data/dickens_model.json'
    dataType: 'json'
    success: (data) ->
      dickensModel = classyfi.SmoothedMarkovModel.fromSerialized data
      alphabet = dickensModel.alphabet

  $.ajax
    url: 'data/austen_model.json'
    dataType: 'json'
    success: (data) ->
      austenModel = classyfi.SmoothedMarkovModel.fromSerialized data
      alphabet = austenModel.alphabet

  latinOut = $ '#a_out'
  englishOut = $ '#b_out'
  resultOut = $ '#result'

  $('#input').on 'input', ->
    val = filter tokenize(@value), alphabet
    if val.length > 4
      a = austenModel.estimate val
      d = dickensModel.estimate val

      latinOut.text a
      englishOut.text d
      
      resultOut.text if a > d then 'AUSTEN' else 'DICKENS'
    else
      resultOut.text '(insufficient text; minimum length 4 words)'

custom = ->
  $('#train').show()

  $('#input').unbind('input').val ''

  $('#a_tag').text 'A'
  $('#b_tag').text 'B'

  $('#a_out').text ''
  $('#b_out').text ''
  $('#result').text ''

  tokenizeWords = (string) ->
    string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split ' '

  tokenizeLetters = (text) ->
    text.toLowerCase().replace(/[^a-z \.]/g, '').split ''
  
  filter = (corpus, alphabet) ->
    result = []
    for token in corpus
      if token in alphabet then result.push token
      else result.push '*'
    return result

  addFrontBack = (corpus, model) ->
    front = corpus[0..Math.floor corpus.length / 2]
    back = corpus[Math.floor(corpus.length / 2)...corpus.length]
    
    model.feed front
    model.feed back

  modelA = null
  modelB = null

  alphabet = []

  tokenize = ->

  order = 0

  $('#run_training').click ->
    corpusA = $('#corpusA').val()
    corpusB = $('#corpusB').val()

    switch $('#tokenizer').val()
      when 'letter_trigrams'
        corpusA = tokenizeLetters corpusA
        corpusB = tokenizeLetters corpusB
        
        alphabet = 'abcdefghijklmnopqrstuvwxyz. '.split ''

        tokenize = tokenizeLetters
        order = 3

      when 'word_unigrams'
        corpusA = tokenizeWords corpusA
        corpusB = tokenizeWords corpusB

        alphabet = classyfi.getMostCommonTokens corpusA.concat(corpusB), 6000
        alphabet.push '*'

        corpusA = filter corpusA, alphabet
        corpusB = filter corpusB, alphabet

        tokenize = (string) ->
          filter tokenizeWords(string), alphabet

        order = 1

      when 'word_bigrams'
        corpusA = tokenizeWords corpusA
        corpusB = tokenizeWords corpusB

        alphabet = classyfi.getMostCommonTokens corpusA.concat(corpusB), 1000
        alphabet.push '*'

        corpusA = filter corpusA, alphabet
        corpusB = filter corpusB, alphabet

        tokenize = (string) ->
          filter tokenizeWords(string), alphabet

        order = 2

    modelA = new classyfi.SmoothedMarkovModel order, alphabet
    modelB = new classyfi.SmoothedMarkovModel order, alphabet

    addFrontBack corpusA, modelA
    addFrontBack corpusB, modelB
  
  aOut = $ '#a_out'
  bOut = $ '#b_out'
  resultOut = $ '#result'

  $('#input').on 'input', ->
    tokens = tokenize @value
    
    if tokens.length > 4
      a = modelA.estimate tokens
      b = modelB.estimate tokens

      aOut.text a
      bOut.text b
      
      resultOut.text if a > b then 'A' else 'B'
    else
      resultOut.text '(insufficient text; minimum length 4 tokens)'

$('#score_write').click -> writers()
$('#score_lang').click -> languages()
$('#score_custom').click -> custom()

languages()
