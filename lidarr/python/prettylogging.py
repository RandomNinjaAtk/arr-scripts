import logging
from os import path, mkdir
from datetime import datetime, timezone
import time
VERSION = 3.0 # Turn into class object to enable state updates

class WRONG_LOG_LEVEL(Exception):
    pass

class PrettyLoggingFormatter(logging.Formatter):  # With the sparkle :D
    def __init__(self, logger_name, version, info_color=None):
        fore_colors = {
            'BLACK': '\033[0;30m',
            'LIGHT_BLACK': '\033[30;1m',
            'RED': '\033[0;31m',
            'LIGHT_RED': '\033[1;31m',
            'GREEN': '\033[0;32m',
            'LIGHT_GREEN': '\033[1;32m',
            'YELLOW': '\033[0;33m',
            'LIGHT_YELLOW': '\033[1;33m',
            'BLUE': '\033[0;34m',
            'LIGHT_BLUE': '\033[1;34m',
            'PURPLE': '\033[0;35m',
            'LIGHT_PURPLE': '\033[1;35m',
            'CYAN': '\033[0;36m',
            'LIGHT_CYAN': '\033[1;36m',
            'GREY': '\033[0;37m',
            'LIGHT_GREY': '\033[1;37m',
            'WHITE': '\033[0;97m',
            'LIGHT_WHITE': '\033[1;97m',
            'RESET': "\033[0m"
        }
        back_colors ={
            'BLACK': '\033[0;40m',
            'LIGHT_BLACK': '\033[40;1m',
            'RED': '\033[0;41m',
            'LIGHT_RED': '\033[1;41m',
            'GREEN': '\033[0;42m',
            'LIGHT_GREEN': '\033[1;42m',
            'YELLOW': '\033[0;43m',
            'LIGHT_YELLOW': '\033[1;43m',
            'BLUE': '\033[0;44m',
            'LIGHT_BLUE': '\033[1;44m',
            'PURPLE': '\033[0;45m',
            'LIGHT_PURPLE': '\033[1;45m',
            'CYAN': '\033[0;46m',
            'LIGHT_CYAN': '\033[1;46m',
            'WHITE': '\033[0;47m',
            'LIGHT_WHITE': '\033[1;47m',
            'RESET': "\033[0m"
        }
        if info_color is None:
            info_color = fore_colors["RESET"]
        else:
            info_color = fore_colors[info_color]

        format = f'%(asctime)s :: {logger_name} :: {version} :: %(levelname)s :: '
        logging.Formatter.formatTime = self.format_time
        self.FORMATS = {
            logging.DEBUG:  format + fore_colors['CYAN'] + '%(message)s' + fore_colors['RESET'],
            logging.INFO: format + info_color + '%(message)s' + fore_colors['RESET'],
            logging.WARNING:  format + fore_colors['YELLOW'] + '%(message)s' + fore_colors['RESET'],
            logging.ERROR:  format + fore_colors['RED'] + '%(message)s' + fore_colors['RESET'],
            logging.CRITICAL:  format + fore_colors['LIGHT_RED'] + '%(message)s' + fore_colors['RESET'],
            logging.FATAL:  format + fore_colors['LIGHT_RED'] + back_colors['LIGHT_WHITE'] + '%(message)s' + fore_colors['RESET']
        }

    def format_time(self,_record, _datefmt):
        t = datetime.now()
        s = t.strftime('%Y-%m-%d %H:%M:%S')
        return s

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


class LoggingFormatter(logging.Formatter):  # Without the sparkle :(
    def __init__(self, logger_name, version):

        datefmt = '%Y-%m-%d %H:%M:%S'
        custom_format = f'{datetime.strftime(datetime.now(), datefmt)} :: {logger_name} :: {version} :: %(levelname)s :: %(message)s'
        self.FORMATS = {
            logging.DEBUG: custom_format,
            logging.INFO: custom_format,
            logging.WARNING: custom_format,
            logging.ERROR: custom_format,
            logging.CRITICAL: custom_format,
            logging.FATAL: custom_format
        }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)






class Prettylogger():
    def __init__(self,logger_name='Logger', version='0.0.0', log_file_path=None, info_color=None, log_level="DEBUG"):
        self.logger_name = logger_name
        self.version = version
        self.log_file_path = log_file_path
        self.info_color = info_color
        self.log_level = log_level

        # Initialize colorama
        self.logger = logging.getLogger(logger_name)
        self.logger.setLevel(self.parse_log_level(self.log_level))
        self.ch = logging.StreamHandler()
        self.update_format()

        if self.log_file_path:
            if not path.exists(path.dirname(self.log_file_path)):
                mkdir(path.dirname(self.log_file_path))
            log_file = logging.FileHandler(self.log_file_path, mode="a", encoding='utf-8')
            log_file.setLevel(logging.DEBUG)
            log_file.setFormatter(LoggingFormatter(logger_name, version))  # Use non-colored formatter
            self.logger.addHandler(log_file)

    def update_format(self):
        #allows info to be updated later
        self.ch.setLevel(logging.DEBUG)
        self.ch.setFormatter(PrettyLoggingFormatter(self.logger_name, self.version, self.info_color))
        self.logger.addHandler(self.ch)

    def parse_log_level(self, log_level):
        if log_level == "DEBUG":
            return logging.DEBUG
        elif log_level == "INFO":
            return logging.INFO
        elif log_level == "WARN":
            return logging.WARN
        elif log_level == "ERROR":
            return logging.ERROR
        elif log_level == "CRITICAL":
            return logging.CRITICAL
        else:
            raise WRONG_LOG_LEVEL(f"Log Level: {log_level}\nLog level must be:\nDEBUG\nINFO\nWARN\nERROR\nCRITICAL")
            exit(1)


if __name__ == '__main__':
    # Good Example
    LOGGER_NAME = 'my_log'
    VERSION = '0.0.0'
    LOG_OUTPUT_PATH = './test/testlog.txt'
    log_settings = Prettylogger(logger_name=LOGGER_NAME, version=VERSION, log_file_path=LOG_OUTPUT_PATH)
    log=log_settings.logger
    log.debug("debug message")
    log.info("info message")
    log.warning("info message")
    log_settings.version = '0.0.2'
    log_settings.update_format()
    log.error("error message")
    log.critical("critical message")
    log.fatal("fatal message")


# Example init

# Logging Consts
# WORKING_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
# NOW = datetime.strftime(datetime.now(), "%b-%d-%Y-%H-%M-%S")
# LOGGER_NAME = 'rpi_backup'
# LOG_OUTPUT_PATH = f'{WORKING_DIR}/logs/Backup-'+NOW+'.log'
#
# log = prettylogging.init_logging(LOGGER_NAME, VERSION, log_file_path=LOG_OUTPUT_PATH, info_color="GREEN")