(function() {
  var custom, languages, writers,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  languages = function() {
    var englishModel, englishOut, latinModel, latinOut, resultOut, tokenize;
    $('#train').hide();
    $('#input').unbind('input').val('');
    $('#a_tag').text('Latin');
    $('#b_tag').text('English');
    $('#a_out').text('');
    $('#b_out').text('');
    $('#result').text('');
    tokenize = function(text) {
      return text.toLowerCase().replace(/[^a-z \.]/g, '').split('');
    };
    latinModel = englishModel = null;
    $.ajax({
      url: 'data/latin_model.json',
      dataType: 'json',
      success: function(data) {
        return latinModel = classyfi.SmoothedMarkovModel.fromSerialized(data);
      }
    });
    $.ajax({
      url: 'data/english_model.json',
      dataType: 'json',
      success: function(data) {
        return englishModel = classyfi.SmoothedMarkovModel.fromSerialized(data);
      }
    });
    latinOut = $('#a_out');
    englishOut = $('#b_out');
    resultOut = $('#result');
    return $('#input').on('input', function() {
      var e, l, val;
      val = tokenize(this.value);
      if (val.length > 15) {
        l = latinModel.estimate(val);
        e = englishModel.estimate(val);
        latinOut.text(l);
        englishOut.text(e);
        return resultOut.text(l > e ? 'LATIN' : 'ENGLISH');
      } else {
        return resultOut.text('(insufficient text; minimum length 15 characters)');
      }
    });
  };

  writers = function() {
    var alphabet, austenModel, dickensModel, englishOut, filter, latinOut, resultOut, tokenize;
    $('#train').hide();
    $('#input').unbind('input').val('');
    $('#a_tag').text('Jane Austen');
    $('#b_tag').text('Charles Dickens');
    $('#a_out').text('');
    $('#b_out').text('');
    $('#result').text('');
    tokenize = function(string) {
      return string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split(' ');
    };
    filter = function(corpus, alphabet) {
      var result, token, _i, _len;
      result = [];
      for (_i = 0, _len = corpus.length; _i < _len; _i++) {
        token = corpus[_i];
        if (__indexOf.call(alphabet, token) >= 0) {
          result.push(token);
        } else {
          result.push('*');
        }
      }
      return result;
    };
    dickensModel = austenModel = null;
    alphabet = [];
    $.ajax({
      url: 'data/dickens_model.json',
      dataType: 'json',
      success: function(data) {
        dickensModel = classyfi.SmoothedMarkovModel.fromSerialized(data);
        return alphabet = dickensModel.alphabet;
      }
    });
    $.ajax({
      url: 'data/austen_model.json',
      dataType: 'json',
      success: function(data) {
        austenModel = classyfi.SmoothedMarkovModel.fromSerialized(data);
        return alphabet = austenModel.alphabet;
      }
    });
    latinOut = $('#a_out');
    englishOut = $('#b_out');
    resultOut = $('#result');
    return $('#input').on('input', function() {
      var a, d, val;
      val = filter(tokenize(this.value), alphabet);
      if (val.length > 4) {
        a = austenModel.estimate(val);
        d = dickensModel.estimate(val);
        latinOut.text(a);
        englishOut.text(d);
        return resultOut.text(a > d ? 'AUSTEN' : 'DICKENS');
      } else {
        return resultOut.text('(insufficient text; minimum length 4 words)');
      }
    });
  };

  custom = function() {
    var aOut, addFrontBack, alphabet, bOut, filter, modelA, modelB, order, resultOut, tokenize, tokenizeLetters, tokenizeWords;
    $('#train').show();
    $('#input').unbind('input').val('');
    $('#a_tag').text('A');
    $('#b_tag').text('B');
    $('#a_out').text('');
    $('#b_out').text('');
    $('#result').text('');
    tokenizeWords = function(string) {
      return string.toLowerCase().replace(/\ *\.\ */g, ' . ').replace(/[^\w \.]/g, '').replace(/\ +/g, ' ').split(' ');
    };
    tokenizeLetters = function(text) {
      return text.toLowerCase().replace(/[^a-z \.]/g, '').split('');
    };
    filter = function(corpus, alphabet) {
      var result, token, _i, _len;
      result = [];
      for (_i = 0, _len = corpus.length; _i < _len; _i++) {
        token = corpus[_i];
        if (__indexOf.call(alphabet, token) >= 0) {
          result.push(token);
        } else {
          result.push('*');
        }
      }
      return result;
    };
    addFrontBack = function(corpus, model) {
      var back, front;
      front = corpus.slice(0, +Math.floor(corpus.length / 2) + 1 || 9e9);
      back = corpus.slice(Math.floor(corpus.length / 2), corpus.length);
      model.feed(front);
      return model.feed(back);
    };
    modelA = null;
    modelB = null;
    alphabet = [];
    tokenize = function() {};
    order = 0;
    $('#run_training').click(function() {
      var corpusA, corpusB;
      corpusA = $('#corpusA').val();
      corpusB = $('#corpusB').val();
      switch ($('#tokenizer').val()) {
        case 'letter_trigrams':
          corpusA = tokenizeLetters(corpusA);
          corpusB = tokenizeLetters(corpusB);
          alphabet = 'abcdefghijklmnopqrstuvwxyz. '.split('');
          tokenize = tokenizeLetters;
          order = 3;
          break;
        case 'word_unigrams':
          corpusA = tokenizeWords(corpusA);
          corpusB = tokenizeWords(corpusB);
          alphabet = classyfi.getMostCommonTokens(corpusA.concat(corpusB), 6000);
          alphabet.push('*');
          corpusA = filter(corpusA, alphabet);
          corpusB = filter(corpusB, alphabet);
          tokenize = function(string) {
            return filter(tokenizeWords(string), alphabet);
          };
          order = 1;
          break;
        case 'word_bigrams':
          corpusA = tokenizeWords(corpusA);
          corpusB = tokenizeWords(corpusB);
          alphabet = classyfi.getMostCommonTokens(corpusA.concat(corpusB), 1000);
          alphabet.push('*');
          corpusA = filter(corpusA, alphabet);
          corpusB = filter(corpusB, alphabet);
          tokenize = function(string) {
            return filter(tokenizeWords(string), alphabet);
          };
          order = 2;
      }
      modelA = new classyfi.SmoothedMarkovModel(order, alphabet);
      modelB = new classyfi.SmoothedMarkovModel(order, alphabet);
      addFrontBack(corpusA, modelA);
      return addFrontBack(corpusB, modelB);
    });
    aOut = $('#a_out');
    bOut = $('#b_out');
    resultOut = $('#result');
    return $('#input').on('input', function() {
      var a, b, tokens;
      tokens = tokenize(this.value);
      if (tokens.length > 4) {
        a = modelA.estimate(tokens);
        b = modelB.estimate(tokens);
        aOut.text(a);
        bOut.text(b);
        return resultOut.text(a > b ? 'A' : 'B');
      } else {
        return resultOut.text('(insufficient text; minimum length 4 tokens)');
      }
    });
  };

  $('#score_write').click(function() {
    return writers();
  });

  $('#score_lang').click(function() {
    return languages();
  });

  $('#score_custom').click(function() {
    return custom();
  });

  languages();

}).call(this);

//# sourceMappingURL=index.js.map
