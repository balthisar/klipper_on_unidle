# Support for an ON_UNIDLE configuration section that can run gcode.
#
# Written in 2025 by Jim Derry <balthisar@gmail.com>
#
# This file is released to the public domain.
import os, logging

class OnUnidle:
    def __init__(self, config):

        self.scriptname, _    = os.path.splitext(os.path.basename(__file__))

        self.printer          = config.get_printer()
        self.gcode            = self.printer.lookup_object('gcode')
        self.gcode_macro      = self.printer.load_object(config, 'gcode_macro')
        self.reactor          = self.printer.get_reactor()
        self.idle_timeout     = self.printer.lookup_object('idle_timeout')

        self.idle_gcode       = self.gcode_macro.load_template(config, 'gcode')
        self.echo_events      = config.getboolean('echo_events'    , False)
        self.display_unidle   = config.getboolean('display_unidle' , True)
        
        if self.display_unidle and not config.has_section('display'):
            raise config.error("Option 'display_unidle' is set to True, but the config section 'display' is missing.")
        
        self.did_idle         = False

        self.printer.register_event_handler('idle_timeout:idle'      , self._idle_handler)
        self.printer.register_event_handler('idle_timeout:printing'  , self._printing_handler)
        self.printer.register_event_handler('idle_timeout:ready'     , self._ready_handler)
        self.printer.register_event_handler('klippy:ready'           , self._klippy_ready_handler)
        self.printer.register_event_handler('menu:action'            , self._menu_handler)

        self.gcode.register_command('SIM_CLICK', self.cmd_SIM_CLICK, desc=self.cmd_SIM_CLICK_help)

        self._output('__init__ complete')

        
    def _klippy_ready_handler(self):
        self.did_idle = True
        # Note that the console isn't available yet, so the output will
        # be present in klippy.log, but not on the console.
        self._output('klippy:ready')


    def _idle_handler(self, params):
        self.did_idle = True
        self._output('idle_timeout:idle')


    def _printing_handler(self, params):
        self._output('idle_timeout:printing')


    def _ready_handler(self, params):
        self._output('idle_timeout:ready, did_idle=%s' % (self.did_idle))
        if self.did_idle:
            try:
                script = self.idle_gcode.render()
                self.gcode.run_script(script)
            except:
                logging.exception('%s: Error executing gcode.' % (self.scriptname))
        
        self.did_idle = False

        
    def _menu_handler(self, *args):
        if self.idle_timeout.state == 'Idle' and self.display_unidle == True:
            # Tickle idle_timeout with this event to wake it up.
            self.printer.send_event('toolhead:sync_print_time', 0.1, 0.2, 0.3)
            self._output('menu:action  %s, %s' % (args[0], args[1]))


    def _output(self, message):
        message = '%s: %s' % (self.scriptname, message)
        if self.echo_events:
            self.gcode.respond_info(message)
        else:
            logging.info(message)
    
    
    cmd_SIM_CLICK_help = "Simulate pressing the display button."
    def cmd_SIM_CLICK(self, gcmd):
        self._menu_handler('click', self.reactor.monotonic())    


def load_config(config):
    return OnUnidle(config)
