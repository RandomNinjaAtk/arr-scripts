import re
from pathlib import Path
from dataclasses import dataclass
from requests import Session
from argparse import ArgumentParser
from sys import argv
from colorama import Fore, init
from telegram import Update
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler
import logging
import os
from datetime import datetime


VERSION = 0.1

# Logging Setup
logging.basicConfig(
    format=f'%(asctime)s :: ARLChecker :: {VERSION} :: %(levelname)s :: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    level=logging.INFO
)
logger = logging.getLogger(__name__)



# Initialize colorama
init(autoreset=True)

# Web agent used to access Deezer
USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:83.0) Gecko/20100101 Firefox/110.0'

@dataclass
class Plan:
    name: str
    expires: str
    active: bool
    download: bool
    lossless: bool
    explicit: bool


@dataclass
class Account:
    id: int
    token: str
    country: str
    plan: Plan


class AuthError(Exception):
    pass


class ParseError(Exception):
    pass


class ServiceError(Exception):
    pass


class DeezerPlatformProvider:
    NAME = 'Deezer'

    BASE_URL = 'http://www.deezer.com'
    API_PATH = '/ajax/gw-light.php'
    SESSION_DATA = {
        'api_token': 'null',
        'api_version': '1.0',
        'input': '3',
        'method': 'deezer.getUserData'
    }

    def __init__(self):
        super().__init__()
        self.session = Session()
        self.session.headers.update({'User-Agent': USER_AGENT})

    def login(self, username, secret):
        try:
            res = self.session.post(
                self.BASE_URL + self.API_PATH,
                cookies={'arl': secret},
                data=self.SESSION_DATA
            )
            res.raise_for_status()
        except Exception as error:
            logger.error(Fore.RED + 'Could not connect! Service down, API changed, wrong credentials or code-related issue.' + Fore.WHITE)
            raise ConnectionError()

        self.session.cookies.clear()

        try:
            res = res.json()
        except Exception as error:
            logger.error(Fore.RED + "Could not parse JSON response from DEEZER!" + Fore.WHITE)
            raise ParseError()

        if 'error' in res and res['error']:
            logger.error(Fore.RED + "Deezer returned the following error:{}".format(res["error"]) + Fore.WHITE)
            raise ServiceError()

        res = res['results']

        if res['USER']['USER_ID'] == 0:
            logger.error(Fore.RED+"ARL Token Expired. Update the token in extended.conf"+Fore.WHITE)
            raise AuthError()

        return Account(username, secret, res['COUNTRY'], Plan(
            res['OFFER_NAME'],
            'Unknown',
            True,
            True,
            res['USER']['OPTIONS']['web_sound_quality']['lossless'],
            res['USER']['EXPLICIT_CONTENT_LEVEL']
        ))
    
    
class LidarrExtendedAPI:
    # sets new token to  extended.conf
    def __init__(self, new_arl_token):
        workingDir = Path(os.getcwd())
        print(workingDir)
        #self.parentDir = str(workingDir.parents[1])
        self.parentDir = str(workingDir.parents[3])
        print(self.parentDir)
        self.extendedConfDir = self.parentDir + '/config/extended.conf'
        self.newARLToken = new_arl_token
        self.arlToken = None
        self.arlLineText = None
        self.arlLineIndex = None
        self.fileText = None
        self.enable_telegram_bot = False
        self.telegram_bot_running = False
        self.telegram_bot_token = None
        self.telegram_user_chat_id = None
        self.telegramBotEnableLineText = None
        self.telegramBotEnableLineIndex = None

        self.bot = None
        self.parse_extended_conf()



    def parse_extended_conf(self):
        deezer_active = False
        self.arlToken = None
        arl_token_match = None
        re_search_pattern = r'"([^"]*)"'
        try:  # Try to open extended.conf and read all text into a var.
            with open(self.extendedConfDir, 'r', encoding='utf-8') as file:
                self.fileText = file.readlines()
                file.close()
        except:
            logger.error(f"Could not find {self.extendedConfDir}")
            exit(1)
        # Ensure Deezer is enabled and ARL token is populated
        for line in self.fileText:
            if 'dlClientSource="deezer"' in line or 'dlClientSource="both"' in line:
                deezer_active = True
            if 'arlToken=' in line:
                self.arlLineText = line
                self.arlLineIndex = self.fileText.index(self.arlLineText)
                arl_token_match = re.search(re_search_pattern, line)
                break

        # ARL Token wrong flag error handling.
        if arl_token_match is None:
            logger.error("ARL Token not found in extended.conf. Exiting")
            exit(1)
        elif deezer_active is False:
            logger.error("Deezer not set as an active downloader in extended.conf. Exiting")
            file.close()
            exit(1)
        self.arlToken = arl_token_match[0]
        logger.info('ARL Found in extended.conf')

        for line in self.fileText:
            if 'telegramBotEnable=' in line:
                self.telegramBotEnableLineText = line
                self.telegramBotEnableLineIndex = self.fileText.index(self.telegramBotEnableLineText)
                self.enable_telegram_bot = re.search(re_search_pattern, line)[0].replace('"', '').lower() in 'true'
            if 'telegramBotToken=' in line:
                self.telegram_bot_token = re.search(re_search_pattern, line)[0].replace('"', '')
            if 'telegramUserChatID=' in line:
                self.telegram_user_chat_id = re.search(re_search_pattern, line)[0].replace('"', '')
                

        if self.enable_telegram_bot:
            logger.info('Telegram bot is enabled.')
            if self.telegram_bot_token is None or self.telegram_user_chat_id is None:
                logger.error('Telegram bot token or user chat ID not set in extended.conf. Exiting')
                exit(1)
        else:
            logger.info('Telegram bot is disabled. Set the flag in extended.conf to enable.')

    # Uses DeezerPlatformProvider to check if the token is valid
    def check_token(self, token=None):
        logger.info('Checking ARL Token Validity...')
        if token == '""':
            logger.info(Fore.YELLOW+"No ARL Token set in Extended.conf"+Fore.WHITE)
            self.report_status("NOT SET")
            exit(0)
        if token is None:
            print('Invalid ARL Token Entry')
            return False
        try:
            deezer_check = DeezerPlatformProvider()
            account = deezer_check.login('', token.replace('"',''))
            if account.plan:
                logger.info(Fore.GREEN + f'Deezer Account Found.'+ Fore.WHITE)
                logger.info('-------------------------------')
                logger.info(f'Plan: {account.plan.name}')
                logger.info(f'Expiration: {account.plan.expires}')
                logger.info(f'Active: {Fore.GREEN+"Y" if account.plan.active else "N"}'+Fore.WHITE)
                logger.info(f'Download: {Fore.GREEN+"Y" if account.plan.download else Fore.RED+"N"}'+Fore.WHITE)
                logger.info(f'Lossless: {Fore.GREEN+"Y" if account.plan.lossless else Fore.RED+"N"}'+Fore.WHITE)
                logger.info(f'Explicit: {Fore.GREEN+"Y" if account.plan.explicit else Fore.RED+"N"}'+Fore.WHITE)
                logger.info('-------------------------------')
                self.report_status('VALID')
                return True
        except Exception as e:
            print(e)
            self.report_status('EXPIRED')
            if self.telegram_bot_running:
                return False
            if self.enable_telegram_bot:
                logger.info('Starting Telegram bot...Check Telegram and follow instructions.')
                self.telegram_bot_running = True
                self.start_telegram_bot()
            exit(420)

    def set_new_token(self):  # Re-writes extended.conf with previously read-in text, replacing w/ new ARL
        self.fileText[self.arlLineIndex] = self.arlLineText.replace(self.arlToken, self.newARLToken)
        with open(self.extendedConfDir, 'w', encoding='utf-8') as file:
            file.writelines(self.fileText)
            file.close()
        logger.info("New ARL token written to extended.conf")

    #  After new token is set, clean up notfound and failed downloads to bypass the default 30 day wait
    def clear_not_found(self):
        paths = [self.parentDir + '/config/extended/logs/notfound',self.parentDir+'/config/extended/logs/downloaded/failed/deezer']
        for path in paths:
            for file in os.listdir(path):
                file_to_delete = os.path.join(path,file)
                os.remove(file_to_delete)

    def report_status(self, status):
        f = open("/custom-services.d/python/ARLStatus.txt", "w")
        now = datetime.strftime(datetime.now(),"%b-%d-%Y at %H:%M:%S")
        f.write(f"{now}: ARL Token is {status}.{' Please update arlToken in extended.conf' if status=='EXPIRED' else ''}")
        f.close()

    def start_telegram_bot(self):
        self.bot = TelegramBotControl(self,self.telegram_bot_token,self.telegram_user_chat_id)

    def disable_telegram_bot(self):
        compiled = re.compile(re.escape('true'), re.IGNORECASE)
        self.fileText[self.telegramBotEnableLineIndex] = compiled.sub('false', self.telegramBotEnableLineText)
        with open(self.extendedConfDir, 'w', encoding='utf-8') as file:
            file.writelines(self.fileText)
            file.close()
        logger.info("Telegram Bot Disabled.")




class TelegramBotControl:
    def __init__(self, parent,telegram_bot_token,telegram_user_chat_id):

        async def send_expired_token_notification(application):
            await application.bot.sendMessage(chat_id=self.telegram_chat_id,text='---\U0001F6A8WARNING\U0001F6A8-----\nARL TOKEN EXPIRED\n Update Token by running "/set_token <TOKEN>"\n You can find a new ARL at:\nhttps://rentry.org/firehawk52#deezer-arls\n\n\n Other Commands:\n/cancel - Cancel this session\n/disable - Disable Telegram Bot',disable_web_page_preview=True)
            # TODO: Get Chat ID/ test on new bot

        self.parent = parent
        self.telegram_bot_token = telegram_bot_token
        self.telegram_chat_id = telegram_user_chat_id
        # start bot control
        self.application = ApplicationBuilder().token(self.telegram_bot_token).post_init(send_expired_token_notification).build()
        token_handler = CommandHandler('set_token', self.set_token)
        cancel_handler = CommandHandler('cancel', self.cancel)
        disable_handler = CommandHandler('disable', self.disable_bot)
        self.application.add_handler(token_handler)
        self.application.add_handler(cancel_handler)
        self.application.add_handler(disable_handler)
        self.application.run_polling(allowed_updates=Update.ALL_TYPES)


    async  def disable_bot(self, update, context: ContextTypes.DEFAULT_TYPE):
        self.parent.disable_telegram_bot()
        await update.message.reply_text('Disabled Telegram Bot. \U0001F614\nIf you would like to re-enable,\nset telegramBotEnable to true\nin extended.conf')
        self.application.stop_running()


    async def cancel(self, update, context: ContextTypes.DEFAULT_TYPE):
        await update.message.reply_text('Canceling...ARLToken is still expired.')
        try:
            self.application.stop_running()
        except Exception:
            pass
    async def set_token(self, update, context: ContextTypes.DEFAULT_TYPE):
        try:
            new_token = update.message.text.split('/set_token ')[1]
            if new_token == '':
                raise Exception
        except:
            await update.message.reply_text('Invalid  Entry... please try again.')
            return
        print(new_token)
        logger.info("Testing ARL Token Validity...")
        token_validity = self.parent.check_token(new_token)
        if token_validity:
            await context.bot.send_message(chat_id=update.effective_chat.id, text="ARL valid, applying...")
            self.parent.newARLToken = '"'+new_token+'"'
            self.parent.set_new_token()
            self.parent.arlToken = self.parent.newARLToken
            # TODO Fix this garbage - move functionality out of telegram stuff
            await context.bot.send_message(chat_id=update.effective_chat.id, text="Checking configuration")
            # reparse extended.conf
            self.parent.parse_extended_conf()
            token_validity = self.parent.check_token(self.parent.arlToken)
            if token_validity:
                await context.bot.send_message(chat_id=update.effective_chat.id, text="ARL Updated! \U0001F44D")
                try:
                    await self.application.stop_running()
                except Exception:
                    pass

        else:# If Token invalid
            await update.message.reply_text(text="Token expired or inactive. try another token.")
            return



def main(arlToken = None):
    parser = ArgumentParser(prog='Account Checker', description='Check if Deezer ARL Token is valid')
    parser.add_argument('-c', '--check', help='Check if current ARL Token is active/valid',required=False, default=False, action='store_true')
    parser.add_argument('-n', '--new', help='Set new ARL Token',type = str, required=False, default=False)

    if not argv[1:]:
        parser.print_help()
        parser.exit()

    args = parser.parse_args()
    arlToken_instance = LidarrExtendedAPI(arlToken)

    if args.check is True:
        if arlToken_instance.arlToken == '':
            print("ARL Token not set. re-run with -n flag")
            exit(1)
        try:
            arlToken_instance.check_token(arlToken_instance.arlToken)
        except Exception as e:
            if 'Chat not found' in str(e):
                logger.error(Fore.RED + "Chat not found. Check your chat ID in extended.conf, or start a chat with your bot."+Fore.WHITE)
            elif 'The token' in str(e):
                logger.error(Fore.RED + "Check your Bot Token in extended.conf."+Fore.WHITE)
            else:
                print(e)
            exit(1)


    elif args.new:
        if args.new == '':
            print("Please pass new ARL token as an argument")
            exit(96)

        arlToken_instance.newARLToken = '"'+args.new+'"'
        arlToken_instance.set_new_token()

    else:
        parser.print_help()



if __name__ == '__main__':
    main('FAKETOKEN')
