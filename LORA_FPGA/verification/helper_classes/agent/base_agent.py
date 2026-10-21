from pyuvm import uvm_agent


class BaseAgent(uvm_agent):
    """Base común para los agentes de interfaz del entorno."""

    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.driver = None
        self.monitor = None
