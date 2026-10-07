from logging import Logger

from pyuvm import (uvm_nonblocking_get_port, uvm_nonblocking_peek_port,
                   uvm_scoreboard,
                   uvm_tlm_analysis_fifo)


class BaseScoreboard(uvm_scoreboard):
    """Base común que garantiza que el scoreboard se ejecute al finalizar."""

    def __init__(self, name, parent, port_names):
        super().__init__(name, parent)
        self.port_names = port_names

    def build_phase(self):
        self.checked_one = False
        self.enabled = True
        # pyuvm crea el logger junto con el componente. La anotacion deja
        # explicito que se utiliza directamente la interfaz de logging.
        self.logger: Logger
        self.fifos = {
            name: uvm_tlm_analysis_fifo(f"{name}_fifo", self)
            for name in self.port_names
        }
        self.get_ports = {
            name: uvm_nonblocking_get_port(f"{name}_get_port", self)
            for name in self.port_names
        }
        self.peek_ports = {
            name: uvm_nonblocking_peek_port(f"{name}_peek_port", self)
            for name in self.port_names
        }
        for name in self.port_names:
            setattr(self, f"{name}_export", self.fifos[name].analysis_export)

    def connect_phase(self):
        for name in self.port_names:
            self.get_ports[name].connect(self.fifos[name].get_export)
            self.peek_ports[name].connect(self.fifos[name].peek_export)

    def check_phase(self):
        if self.enabled:
            while any(port.can_get() for port in self.get_ports.values()):
                available = []
                for source, port in self.peek_ports.items():
                    success, event = port.try_peek()
                    if success:
                        available.append((event.time_ns, source))
                _, source = min(available)
                success, event = self.get_ports[source].try_get()
                assert success
                # Los estimulos quedan visibles con la configuracion INFO
                # normal. Las observaciones de monitores permanecen en DEBUG
                # para no inundar la salida de la suite completa.
                log_method = (self.logger.info
                              if event.category.value == "stimulus"
                              else self.logger.debug)
                log_method(
                    "[%s] %s | %s",
                    source,
                    event.kind.value,
                    event.description(),
                )
                try:
                    self.check_event(event, source)
                except AssertionError as error:
                    self.logger.error(
                        "Fallo de scoreboard en %s (%s): %s",
                        source, event.kind.value, error)
                    raise
                self.checked_one = True

    def check_event(self, event, source):
        raise NotImplementedError

    def final_phase(self):
        if self.enabled:
            assert self.checked_one, "El scoreboard no ejecuto check_phase"

    def is_enabled(self):
        return self.enabled
