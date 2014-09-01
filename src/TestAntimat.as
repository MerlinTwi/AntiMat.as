package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.getTimer;
	
	/**
	 * Проверяет шаблоны Antimat на ложные срабатывания
	 */
	[SWF( width = "600", height = "600", scriptTimeLimit="255" )]
    public class TestAntimat extends Sprite
    {
		static private const ABUSIVE_FILE_NAME:String = "text/abusive.txt";
		static private const NOT_ABUSIVE_FILE_NAME:String = "text/not_abusive.txt";
		static private const MASTER_I_MARGARITA_FILE_NAME:String = "text/Master_i_Margarita.txt";
		static private const WIKI_WORDS_FILE_NAME:String = "text/wiki_freq.txt";
		static private const ALL_RU_WORDS_FILE_NAME:String = "text/all_ru_worlds.txt";
		static private const PREDLOG:Array = ['в', 'до', 'из', 'к', 'на', 'не', 'нет', 'да', 'же', 'ее', 'по', 'о', 'от', 'он', 'ох', 'ах', 'с', 'у', 'за', 'об', 'как', 'но'];
		
		private var tf:TextField;
		private var loader:URLLoader;
		private var loaderFileName:String;
		private var loaderHandler:Function;
		private var step:int;
		private var notAbusiveWords:Array;
		private var notAbusiveWordsLength:int;
		private var notAbusiveLastTimePrint:int;
		
		public function TestAntimat() {
			loader = new URLLoader();
			loader.dataFormat = "text";
			loader.addEventListener(Event.COMPLETE, onLoaderComplete);
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderError);
            loader.addEventListener(IOErrorEvent.IO_ERROR, onLoaderError);
			
			tf = new TextField();
			tf.defaultTextFormat = new TextFormat('_sans', 12);
			tf.width = stage.stageWidth;
			tf.height = stage.stageHeight;
			tf.wordWrap = true;
			addChild(tf);
			
			log("Начинаем проверку Antimat, это займет несколько минут...");
			nextStep();
		}
		
		/** Выводит строку в trace и в текстовое поле флешки */
		private function log(...ar):void {
			var s:String = ar.join(' ');
			trace(s);
			if (tf) {
				tf.appendText(s + "\n");
				tf.scrollV = tf.maxScrollV;
			}
		}
		
		/** Переходим к следующей стадии проверки на следующем фрейме, чтобы не зависать. */
		private function nextStep():void {
			addEventListener(Event.ENTER_FRAME, doNextStep);
		}
		private function doNextStep(e:Event):void {
			removeEventListener(Event.ENTER_FRAME, doNextStep);
			switch (++step) {
				case 1: // проверка шаблонов
					testRules();
				break;
				case 2: // проверка матерных слов
					log("Загружаем файл с матерными словами.");
					loadFile(ABUSIVE_FILE_NAME, testAbusive);
				break;
				case 3: // проверка не матерных слов
					log("Загружаем файл с не матерными словами где возможны ложные срабатывания.");
					loadFile(NOT_ABUSIVE_FILE_NAME, testNotAbusive);
				break;
				case 4: // проверка книги.
					// в оригинальном тексте книги содержались оскорбительные слова
					// пришлось их заменить на *** :)
					log("Проверим текст книги Мастер и Маргарита");
					loadFile(MASTER_I_MARGARITA_FILE_NAME, testNotAbusive);
				break;
				case 5: // проверка часто встречающихся слов на википедии
					log("Проверим самые часто встречающиеся слова в википедии");
					loadFile(WIKI_WORDS_FILE_NAME, testNotAbusive);
				break;
				case 6:
					// проверка всех русских слов в комбинации с предлогами
					// именно в таком варианте больше всего ложных срабатываний
					log("Проверим отдельные русские слова в комбинации с различными предлогами");
					log("Это надолго!");
					loadFile(ALL_RU_WORDS_FILE_NAME, testNotAbusiveWithSuffix);
				break;
				default:
					log("Проверка законцена.");
			}
		}
		
		
		/** Проверка шаблонов */
		private function testRules():void {
			var s:String = Antimat.checkRules();
			if (s) {
				log(s);
				log("Проверка прервана из-за ошибок в правилах.");
			} else {
				log("Все правила корректны.");
				nextStep();
			}
		}
		
		/** проверка матерных слов, все строки должны быть заменены */
		private function testAbusive(s:String):void {
			var errors:int;
			var words:Array = s.split('\r').join('').split("\n");
			for each (var w:String in words) if (w) {
				if (w == Antimat.removeMat(w)) {
					log("ОШИБКА. Не произошло замены матерных слов:", w);
					if (++errors > 10) break;
				}
			}
			if (errors) {
				log("Проверка прервана. Исправьте правила.");
			} else {
				log('Успешно закончена проверка матерных слов из файла: ' + loaderFileName);
				nextStep();
			}
		}
		
		/** проверка не матерных слов. замен быть не должно */
		private function testNotAbusive(text:String):void {
			notAbusiveWords = text.split('\r').join('').split("\n");
			notAbusiveWordsLength = notAbusiveWords.length;
			notAbusiveLastTimePrint = 0;
			// там есть большие тексты, чтобы не зависать
			// проверяем по чуть-чуть в ENTER_FRAME
			addEventListener(Event.ENTER_FRAME, doTestNotAbusive);
		}
		private function doTestNotAbusive(e:Event):void {
			var tm1:int = getTimer();
			var errors:int;
			while (getTimer() - tm1 < 200 && notAbusiveWords.length > 0) {
				var w:String = notAbusiveWords.pop();
				var s:String = Antimat.removeMat(w, true);
				if (w != s) {
					log('ОШИБКА. Ложное срабатывание правила "' + Antimat.LAST_USED_PATTERN + '" в тексте ' + s);
					if (++errors > 10) break;
				}
			}
			if (errors) {
				removeEventListener(Event.ENTER_FRAME, doTestNotAbusive);
				log("Проверка прервана. Исправьте правила.");
			} else if (notAbusiveWords.length == 0) {
				removeEventListener(Event.ENTER_FRAME, doTestNotAbusive);
				log('Успешно закончена проверка не матерных слов из файла: ' + loaderFileName);
				nextStep();
			} else if (getTimer() - notAbusiveLastTimePrint > 1000) {
				// каждую секунду информируем юзера, что мы не зависли :)
				notAbusiveLastTimePrint = getTimer();
				log(Math.round((1 - notAbusiveWords.length / notAbusiveWordsLength) * 100) + '% ...');
			}
		}
		
		/** проверка отдельных не матерных слов с приставками и суффиксами. замен быть не должно */
		private function testNotAbusiveWithSuffix(text:String):void {
			notAbusiveWords = text.split('\r').join('').split("\n");
			notAbusiveWordsLength = notAbusiveWords.length;
			notAbusiveLastTimePrint = 0;
			// очень долгая проверка
			addEventListener(Event.ENTER_FRAME, doTestNotAbusiveWithSuffix);
		}
		private function doTestNotAbusiveWithSuffix(e:Event):void {
			var tm1:int = getTimer();
			var errors:int;
			while (getTimer() - tm1 < 200 && notAbusiveWords.length > 0) {
				var w:String = notAbusiveWords.pop();
				// комбинируем слово со всевозможными предлогами
				var withPredlogs:String = w + ' ' + PREDLOG.join(' ' + w + ' ' ) + ' ' + w;
				var s:String = Antimat.removeMat(withPredlogs, true);
				if (withPredlogs != s) {
					// возможно это некорректная комбинация с предлогом
					var itError:Boolean = true;
					for each (var wp:String in WRONG_PREDLOGS)
						if (s.indexOf(wp) >= 0) {
							itError = false;
							break;
						}
					if (itError) {
						log('ОШИБКА. Ложное срабатывание правила "' + Antimat.LAST_USED_PATTERN + '" в тексте ' + s);
						if (++errors > 10) break;
					}
				}
			}
			if (errors) {
				removeEventListener(Event.ENTER_FRAME, doTestNotAbusiveWithSuffix);
				log("Проверка прервана. Исправьте правила.");
			} else if (notAbusiveWords.length == 0) {
				removeEventListener(Event.ENTER_FRAME, doTestNotAbusiveWithSuffix);
				log('Успешно закончена проверка всех русских слов.');
				nextStep();
			} else if (getTimer() - notAbusiveLastTimePrint > 4000) {
				// информируем юзера, что мы не зависли :)
				notAbusiveLastTimePrint = getTimer();
				log(Math.round((1 - notAbusiveWords.length / notAbusiveWordsLength) * 100) + '% ...');
			}
		}
		
		/** Загрузить указанный текстовый файл и передать его содержимое в указанную функцию */
		private function loadFile(fileName:String, onLoadFileHandler:Function/*(test:String)*/):void {
			loaderFileName = fileName;
			loaderHandler = onLoadFileHandler;
			loader.load(new URLRequest(fileName));
		}
		
		/** Успешно загружен файл */
		private function onLoaderComplete(e:Event):void {
			var text:String = String(loader.data);
			loaderHandler(text);
		}
		
		/** Ошибка загрузки файла */
		private function onLoaderError(e:Event):void {
			log('Ошибка загрузки файла "' + loaderFileName + '"', e);
			log("Проверка прервана");
		}
		
		/**
		 * Встречаются некорректные варианты слов с предлогами на которые срабатывает фильтр
		 * т.к. предлоги тупо добавляются все подряд без каких-либо правил
		 */
		static private const WRONG_PREDLOGS:Array = [
			'<С ЦУКАТ', '<С ЦУКАНИЕ>', '<НА ХЕРШИ-КО', '<ПО ХЕРТЕЛЬ>',
			'<НА ХЕРСОН', '<НА ХЕРИК>', '<ПО ХЕРЕС', '<ПО ХЕРДЕЛЬ>',
			'<ОХ УЯСН', '<ОХ УЯРЦ', '<ОХ УЯРЕЦ>', '<С УЧЕН', '<С УКИСАНИЕ>',
			'<С УКИПАНИЕ>', '<ОХ УЙМ', '<ОХ УЙГ', '<ОХ УЙТ', '<ОХ УИН', '<ОХ УИМ', '<ОХ УИЛ', '<ОХ УИК',
			'<ОХ УЕСТ', '<ОХ УЕЛО>', '<ОХ УЕЛИ>', '<ОХ УЕЛА>', '<АХ УЕЛ>', '<ОХ УЕЗ', '<АХ УЕВ>',
			'<ОХ УЕМ>', '<ОХ УЁМ>', '<С У-КАМЕНОГОРСК', '<ОТ СОСИТЕ>', '<ОТ СОСАЛ', '<С РУЛЬ>',
			'<У РОД>', '<С РАКИЯ>', '<С РАКИ>', '<С РАКА>', '<С ОСИ>', '<ЗА ЛУП',
			'ИХ У ИХ', '<У Е-БИЗНЕ', '<С УЧЁНОСТЬ>', 
		];
    }
}
