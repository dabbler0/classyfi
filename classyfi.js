(function() {
  var Category, Classifier, Estimator, MarkovModel, SmoothedMarkovModel, exports, getMostCommonTokens,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  exports = {};

  exports.Estmator = Estimator = (function() {
    function Estimator() {}

    Estimator.prototype.feed = function(tokens) {};

    Estimator.prototype.estimate = function(tokens) {
      return 0;
    };

    return Estimator;

  })();

  exports.MarkovModel = MarkovModel = (function(_super) {
    __extends(MarkovModel, _super);

    function MarkovModel(order, alphabet, count, suppressInit) {
      var token, _i, _len, _ref;
      this.order = order;
      this.alphabet = alphabet;
      this.count = count != null ? count : 0;
      if (suppressInit == null) {
        suppressInit = false;
      }
      if (this.order !== 0) {
        this.children = {};
        if (!suppressInit) {
          _ref = this.alphabet;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            token = _ref[_i];
            this.children[token] = new MarkovModel(this.order - 1, this.alphabet);
          }
        }
      }
    }

    MarkovModel.prototype.increment = function(vector) {
      this.count += 1;
      if (this.order !== 0) {
        return this.children[vector[0]].increment(vector.slice(1));
      }
    };

    MarkovModel.prototype.smoothHO = function(other) {
      var bucketCounts, bucketSizes, newChildren, result, smoothedCounts, token, tokenCount, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3;
      if (this.order !== 0) {
        bucketCounts = {};
        bucketSizes = {};
        _ref = this.alphabet;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          token = _ref[_i];
          tokenCount = this.children[token].count;
          bucketCounts[tokenCount] = 1;
          if (bucketSizes[tokenCount] == null) {
            bucketSizes[tokenCount] = 0;
          }
          bucketSizes[tokenCount] += 1;
        }
        _ref1 = this.alphabet;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          token = _ref1[_j];
          bucketCounts[this.children[token].count] += other.children[token].count;
        }
        smoothedCounts = {};
        _ref2 = this.alphabet;
        for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
          token = _ref2[_k];
          smoothedCounts[token] = bucketCounts[this.children[token].count] / bucketSizes[this.children[token].count];
        }
        result = new MarkovModel(this.order, this.alphabet, this.count, true);
        newChildren = {};
        _ref3 = this.alphabet;
        for (_l = 0, _len3 = _ref3.length; _l < _len3; _l++) {
          token = _ref3[_l];
          newChildren[token] = this.children[token].smoothHO(other.children[token]);
          newChildren[token].count = smoothedCounts[token];
        }
        result.children = newChildren;
        return result;
      } else {
        return new MarkovModel(this.order, this.alphabet, this.count);
      }
    };

    MarkovModel.prototype.add = function(other) {
      var result, token, _i, _len, _ref;
      result = new MarkovModel(this.order, this.alphabet, this.count + other.count, true);
      if (this.order !== 0) {
        _ref = this.alphabet;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          token = _ref[_i];
          result.children[token] = this.children[token].add(other.children[token]);
        }
      }
      return result;
    };

    MarkovModel.prototype.normalize = function() {
      var token, total, _i, _j, _len, _len1, _ref, _ref1, _results;
      if (this.order !== 0) {
        total = 0;
        _ref = this.alphabet;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          token = _ref[_i];
          total += this.children[token].count;
        }
        _ref1 = this.alphabet;
        _results = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          token = _ref1[_j];
          this.children[token].count /= total;
          _results.push(this.children[token].normalize());
        }
        return _results;
      }
    };

    MarkovModel.prototype.clearCache_ = function() {
      return this.normalize();
    };

    MarkovModel.prototype.feed = function(tokens) {
      var i, _i, _ref, _ref1, _results;
      _results = [];
      for (i = _i = _ref = this.order, _ref1 = tokens.length; _ref <= _ref1 ? _i < _ref1 : _i > _ref1; i = _ref <= _ref1 ? ++_i : --_i) {
        _results.push(this.increment(tokens.slice(i - this.order, +i + 1 || 9e9)));
      }
      return _results;
    };

    MarkovModel.prototype.getProbability = function(ngram, i) {
      if (i == null) {
        i = 0;
      }
      if (this.order === 0) {
        return 0;
      } else {
        return Math.log(this.children[ngram[i]].count) + this.children[ngram[i]].getProbability(ngram, i + 1);
      }
    };

    MarkovModel.prototype.estimate = function(tokens) {
      var i, ngram, probability, _i, _ref, _ref1;
      if (this.mustClearCache_) {
        this.clearCache_();
      }
      this.mustClearCache_ = false;
      probability = 0;
      for (i = _i = _ref = this.order, _ref1 = tokens.length; _ref <= _ref1 ? _i < _ref1 : _i > _ref1; i = _ref <= _ref1 ? ++_i : --_i) {
        ngram = tokens.slice(i - this.order, +i + 1 || 9e9);
        if (this.getProbability(ngram) !== this.getProbability(ngram)) {
          console.log('OOPS: cannot get prob for', ngram);
        }
        probability += this.getProbability(ngram);
      }
      return probability;
    };

    MarkovModel.prototype.getRandomToken = function(startVector) {
      var barrier, i, obj, point, token, _i, _j, _len, _ref, _ref1;
      obj = this;
      for (i = _i = 0, _ref = this.order - 1; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        obj = obj.children[startVector[i]];
      }
      point = 0;
      barrier = Math.random();
      _ref1 = this.alphabet;
      for (_j = 0, _len = _ref1.length; _j < _len; _j++) {
        token = _ref1[_j];
        point += obj.children[token].count;
        if (point > barrier) {
          return token;
        }
      }
      return this.alphabet[this.alphabet.length - 1];
    };

    MarkovModel.prototype.generateRandom = function(n) {
      var char, startVector, str, _i;
      startVector = (function() {
        var _i, _ref, _results;
        _results = [];
        for (_i = 0, _ref = this.order - 1; 0 <= _ref ? _i < _ref : _i > _ref; 0 <= _ref ? _i++ : _i--) {
          _results.push(this.alphabet[Math.floor(Math.random() * this.alphabet.length)]);
        }
        return _results;
      }).call(this);
      str = '';
      for (_i = 1; 1 <= n ? _i <= n : _i >= n; 1 <= n ? _i++ : _i--) {
        char = this.getRandomToken(startVector);
        startVector.shift();
        startVector.push(char);
        str += char;
      }
      return str;
    };

    MarkovModel.prototype.serialize = function() {
      var dict, token, _i, _len, _ref;
      if (this.order !== 0) {
        dict = {};
        _ref = this.alphabet;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          token = _ref[_i];
          dict[token] = this.children[token].serialize();
        }
        return {
          count: this.count,
          children: dict
        };
      } else {
        return this.count;
      }
    };

    return MarkovModel;

  })(Estimator);

  MarkovModel.fromSerialized = function(s, alphabet) {
    var childrenDict, result, token, _i, _len;
    if (alphabet == null) {
      alphabet = null;
    }
    if (typeof s === 'number' || s instanceof Number) {
      return new MarkovModel(0, alphabet, s);
    } else {
      if (alphabet == null) {
        alphabet = [];
        for (token in s.children) {
          alphabet.push(token);
        }
      }
      childrenDict = {};
      for (_i = 0, _len = alphabet.length; _i < _len; _i++) {
        token = alphabet[_i];
        childrenDict[token] = MarkovModel.fromSerialized(s.children[token]);
      }
      result = new MarkovModel(childrenDict[alphabet[0]].order + 1, alphabet, s.count, true);
      result.children = childrenDict;
      return result;
    }
  };

  exports.SmoothedMarkovModel = SmoothedMarkovModel = (function(_super) {
    __extends(SmoothedMarkovModel, _super);

    function SmoothedMarkovModel(order, alphabet, suppressInit) {
      this.order = order;
      this.alphabet = alphabet;
      if (suppressInit == null) {
        suppressInit = false;
      }
      if (!suppressInit) {
        this.front = new MarkovModel(this.order, this.alphabet);
        this.back = new MarkovModel(this.order, this.alphabet);
        this.smoothed = null;
      }
      this.mustClearCache_ = false;
    }

    SmoothedMarkovModel.prototype.feed = function(tokens) {
      if (this.front.count < this.back.count) {
        this.front.feed(tokens);
      } else {
        this.back.feed(tokens);
      }
      return this.mustClearCache_ = true;
    };

    SmoothedMarkovModel.prototype.clearCache_ = function() {
      this.smoothed = this.front.smoothHO(this.back).add(this.back.smoothHO(this.front));
      return this.smoothed.normalize();
    };

    SmoothedMarkovModel.prototype.estimate = function(tokens) {
      if (this.mustClearCache_) {
        this.clearCache_();
      }
      this.mustClearCache_ = false;
      return this.smoothed.estimate(tokens);
    };

    SmoothedMarkovModel.prototype.serialize = function() {
      return {
        front: this.front.serialize(),
        back: this.back.serialize(),
        smoothed: this.smoothed.serialize()
      };
    };

    return SmoothedMarkovModel;

  })(Estimator);

  SmoothedMarkovModel.fromSerialized = function(s) {
    var back, front, result, smoothed;
    front = MarkovModel.fromSerialized(s.front);
    back = MarkovModel.fromSerialized(s.back);
    smoothed = MarkovModel.fromSerialized(s.smoothed);
    result = new SmoothedMarkovModel(front.order, front.alphabet, true);
    result.front = front;
    result.back = back;
    result.smoothed = smoothed;
    return result;
  };

  exports.Category = Category = (function() {
    function Category(estimator) {
      this.estimator = estimator;
      this.tokenCount = 0;
    }

    Category.prototype.feed = function(tokens) {
      this.estimator.feed(tokens);
      return this.tokenCount += tokens.length;
    };

    Category.prototype.estimate = function(tokens) {
      return this.estimator.estimate(tokens);
    };

    return Category;

  })();

  exports.Classifier = Classifier = (function() {
    function Classifier(categories) {
      this.categories = categories;
    }

    Classifier.prototype.classify = function(tokens) {
      var category, categoryProbabilities, i, total, _i, _j, _len, _len1, _ref, _ref1;
      total = 0;
      _ref = this.categories;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        category = _ref[_i];
        total += category.tokenCount;
      }
      categoryProbabilities = [];
      _ref1 = this.categories;
      for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
        category = _ref1[i];
        categoryProbabilities[i] = Math.log(category.tokenCount) + category.estimate(tokens);
      }
      return categoryProbabilities;
    };

    return Classifier;

  })();

  exports.getMostCommonTokens = getMostCommonTokens = function(array, n) {
    var best, count, counts, i, record, token, _i, _j, _len, _len1;
    counts = {};
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      token = array[_i];
      if (counts[token] == null) {
        counts[token] = 0;
      }
      counts[token] += 1;
    }
    best = [];
    for (token in counts) {
      count = counts[token];
      if (best.length === 0) {
        best.push({
          count: count,
          token: token
        });
      } else {
        for (i = _j = 0, _len1 = best.length; _j < _len1; i = ++_j) {
          record = best[i];
          if (count > record.count) {
            best.splice(i, 0, {
              count: count,
              token: token
            });
            if (best.length > n) {
              best.pop();
            }
            break;
          }
        }
      }
    }
    return (function() {
      var _k, _len2, _results;
      _results = [];
      for (_k = 0, _len2 = best.length; _k < _len2; _k++) {
        record = best[_k];
        _results.push(record.token);
      }
      return _results;
    })();
  };

  window.classyfi = exports;

}).call(this);

//# sourceMappingURL=classyfi.js.map
