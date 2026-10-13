import inspect
import sys

from pyuvm import uvm_sequence, uvm_test


class BaseTest(uvm_test):
    """Construye el environment y ejecuta la secuencia elegida por el test."""

    sequence = None

    def build_phase(self):
        from environment import Env
        self.env = Env("env", self)

    def end_of_elaboration_phase(self):
        raise NotImplementedError(
            "El test debe asignar self.sequence en end_of_elaboration_phase")

    async def run_phase(self):
        self.raise_objection()
        assert isinstance(self.sequence, uvm_sequence), (
            "La prueba no instancio una uvm_sequence")

        # Cada test documenta su objetivo en el docstring del modulo. Se
        # muestra al comenzar para que la ejecucion de la suite no sea una
        # sucesion opaca de nombres de archivo.
        test_module = sys.modules[self.sequence.__class__.__module__]
        description = inspect.getdoc(test_module)
        self.logger.info("TEST: %s", description or self.__class__.__name__)

        self.sequence.logger = self.logger
        await self.sequence.start(self.env.seqr)
        self.drop_objection()
