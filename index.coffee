module.exports = (Module) ->
	color = require 'irc-colors'
	request = require 'request'
	partsOfSpeech = [
		"noun"
		"adjective"
		"verb"
		"adverb"
		"interjection"
		"pronoun"
		"preposition"
		"abbreviation"
		"affix"
		"article"
		"auxiliary-verb"
		"conjunction"
		"definite-article"
		"family-name"
		"given-name"
		"idiom"
		"imperative"
		"noun-plural"
		"noun-posessive"
		"past-participle"
		"phrasal-prefix"
		"proper-noun"
		"proper-noun-plural"
		"proper-noun-posessive"
		"suffix"
		"verb-intransitive"
		"verb-transitive"
	]
	
	class WordnikModule extends Module
		shortName: "Wordnik"
		helpText:
			default: "Accesses Wordnik API for dictionary functions. Current commands: define, example, rhyme, synonym, antonym, hypernym, hyponym, wordoftheday, randomwords"
			define: "Gets the definition for (case-sensitive) words."
			example: "Gets an example sentence using the given (case-sensitive) word."
			rhyme: "Gets the first 30 words that rhyme with the given word."
			synonym: "Gets synonyms for the given word."
			antonym: "Gets antonyms for the given word."
			hypernym: "Gets hypernyms for the given word."
			hyponym: "Gets hyponym for the given word."
			wordoftheday: "Gets the word of the day."
			randomwords: "Gets some random words. Available parts of speech: noun, adjective, verb, adverb, interjection, pronoun, preposition, abbreviation, affix, article, auxiliary-verb, conjunction, definite-article, family-name, given-name, idiom, imperative, noun-plural, noun-posessive, past-participle, phrasal-prefix, proper-noun, proper-noun-plural, proper-noun-posessive, suffix, verb-intransitive, verb-transitive"
		usage:
			define: "define [word]"
			example: "example [word]"
			rhyme: "rhyme [word]"
			synonym: "synonym [word]"
			antonym: "antonym [word]"
			hypernym: "hypernym [word]"
			hyponym: "hyponym [word]"
			wordoftheday: "wordoftheday"
			randomwords: "randomwords {part-of-speech}"
			
		constructor: (moduleManager) ->
			super(moduleManager)
			if not @getApiKey('wordnik')?
				console.error "WordnikModule will not work without a 'wordnik' api key."

			@addRoute "define :word", (origin, route) =>
				@callAPI origin, route.params.word, 'definitions', {limit: 1}, (err, res, body) =>
					if err? or res.statusCode isnt 200
						@reply origin, "Error: #{err?.message or res.statusCode}"
					else if body.length is 0
						@reply origin, "No definitions found."
					else
						{word, text, partOfSpeech} = body[0]
						@reply origin, "#{word}: (#{color.green partOfSpeech}) #{color.olive text}"

			@addRoute "example :word", (origin, route) =>
				@callAPI origin, route.params.word, 'topExample', {}, (err, res, body) =>
					if res.statusCode is 404
						@reply origin, "No examples found."
					else if err? or res.statusCode isnt 200
						@reply origin, "Error: #{err?.message or res.statusCode}"
					else
						{word, text} = body
						@reply origin, "#{word}: #{color.green text}"

			registerRelatedWordType = (type, cmdPrefix = '') =>
				@addRoute "#{cmdPrefix+type} :word", (origin, route) =>
					params = 
						relationshipTypes: type
						limitPerRelationshipType: 30
					@callAPI origin, route.params.word, 'relatedWords', params, (err, res, body) =>
						if err? or res.statusCode isnt 200
							@reply origin, "Error: #{err?.message or res.statusCode}"
						else if body.length is 0
							@reply origin, "No #{type}s found."
						else
							{words} = body[0]
							@reply origin, "#{route.params.word} #{type}s: #{words.join ', '}"

			registerRelatedWordType 'rhyme'
			registerRelatedWordType 'synonym'
			registerRelatedWordType 'antonym'
			registerRelatedWordType 'hypernym'
			registerRelatedWordType 'hyponym'

	
			@addRoute "wordoftheday", (origin, route) =>
				@callAPI origin, null, 'wordOfTheDay', {}, (err, res, body) =>
					if err? or res.statusCode isnt 200
						@reply origin, "Error: #{err?.message or res.statusCode}"
					else
						@reply origin, "Todays word of the day: #{body.word}"
				
			
			registerRandomWords = (origin, route) =>
				params =
					hasDictionaryDef: true
					minLength: 3
					limit: 10
				params.includePartOfSpeech = route.params.pos if route.params.pos?
				@callAPI origin, null, 'randomWords', params, (err, res, body) =>
					if err? or res.statusCode isnt 200
						@reply origin, "Error: #{err?.message or res.statusCode}"
					else
						@reply origin, "I can think of these off the top of my head: #{(i.word for i in body).join ', '}"

			@addRoute "randomwords", registerRandomWords
			@addRoute "randomwords :pos", registerRandomWords

		callAPI: (origin, word, command, params, cb) ->
			params.api_key = @getApiKey('wordnik')
			if not params.api_key?
				@reply origin, "This command needs a 'wordnik' API key. Add it with !set-api-key wordnik [key]"
				return
			paramStr = ("#{k}=#{v}" for k,v of params).join '&'
			if word?
				url = "http://api.wordnik.com:80/v4/word.json/#{encodeURIComponent word}/#{command}?#{paramStr}"
			else
				url = "http://api.wordnik.com:80/v4/words.json/#{command}?#{paramStr}"
			request
				url: url
				json: true
				(err, res, body) =>
					try
						cb err, res, body
					catch e
						@reply origin, "Error calling API: #{e}"
						console.error e.stack if e.stack?
					


	WordnikModule