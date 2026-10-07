import argparse
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERIFY = ROOT / "verification"
RTL = ROOT / "LORA_FPGA.srcs" / "sources_1" / "new"

COMMON_SPI = [
    RTL / "block_ram.vhd",
    RTL / "spi_pin_driver.vhd",
    RTL / "spi_frame_controller.vhd",
]
COMMON_UART = [
    RTL / "uart_tx.vhd",
    RTL / "uart_rx.vhd",
    RTL / "myUart.vhd",
]
SX1278_RTL = [
    RTL / "sx1278_controller_pkg.vhd",
    *COMMON_SPI,
    RTL / "spi_register_access.vhd",
    RTL / "spi_sequence_controller.vhd",
    RTL / "sx1278_config_registers.vhd",
    RTL / "sx1278_config_manager.vhd",
    RTL / "sx1278_tx_manager.vhd",
    RTL / "sx1278_rx_manager.vhd",
    RTL / "sx1278_controller.vhd",
]
UART_OUTPUT_RTL = [
    RTL / "uart_command_pkg.vhd",
    RTL / "uart_response_serializer.vhd",
    RTL / "uart_rx_serializer.vhd",
    RTL / "uart_tx_master.vhd",
]

SUITES = {
    "spi": {
        "top": "spi_verification_wrapper",
        "module": "testbench",
        "test_dir": VERIFY / "tests" / "SPI",
        "sources": [*COMMON_SPI,
                    VERIFY / "tests" / "SPI" / "hdl" /
                    "spi_verification_wrapper.vhd"],
        "parameters": {
            "RAM_DEPTH": 8,
            "CLK_FREQ_HZ": 1_000_000,
            "SPI_FREQ_HZ": 100_000,
            "INTER_FRAME_DELAY_US": 1,
        },
    },
    "uart": {
        "top": "uart_verification_wrapper",
        "module": "testbench",
        "test_dir": VERIFY / "tests" / "UART",
        "sources": [*COMMON_UART,
                    VERIFY / "tests" / "UART" / "hdl" /
                    "uart_verification_wrapper.vhd"],
        "parameters": {"BAUD_RATE": 100_000, "CLK_FREQ_HZ": 1_000_000,
                       "DATA_SIZE": 8},
    },
    "command_decoder": {
        "top": "command_decoder_verification_wrapper",
        "module": "testbench",
        "test_dir": VERIFY / "tests" / "COMMAND_DECODER",
        "sources": [
            RTL / "sx1278_controller_pkg.vhd",
            RTL / "uart_command_pkg.vhd",
            RTL / "command_acceptance_validator.vhd",
            RTL / "command_decoder.vhd",
            VERIFY / "tests" / "COMMAND_DECODER" / "hdl" /
            "command_decoder_verification_wrapper.vhd",
        ],
        "parameters": {"MAX_DATA_BYTES": 50},
    },
    "uart_tx_master": {
        "top": "uart_tx_master_verification_wrapper",
        "module": "testbench",
        "test_dir": VERIFY / "tests" / "UART_TX_MASTER",
        "sources": [*UART_OUTPUT_RTL,
                    VERIFY / "tests" / "UART_TX_MASTER" / "hdl" /
                    "uart_tx_master_verification_wrapper.vhd"],
        "parameters": {"MAX_DATA_BYTES": 50},
    },
    "sx1278": {
        "top": "sx1278_controller_verification_wrapper",
        "module": "testbench",
        "test_dir": VERIFY / "tests" / "SX1278",
        "sources": [*SX1278_RTL,
                    VERIFY / "tests" / "SX1278" / "hdl" /
                    "sx1278_controller_verification_wrapper.vhd"],
        "parameters": {"MAX_DATA_BYTES": 50, "CLK_FREQ_HZ": 1_000_000,
                       "SPI_FREQ_HZ": 100_000, "RESET_TIME_MS": 1},
    },
    "lora_uart": {
        "top": "lora_top_verification_wrapper",
        "module": "testbench",
        "test_dir": VERIFY / "tests" / "LORA_UART",
        "sources": [
            RTL / "uart_command_pkg.vhd",
            *COMMON_UART,
            RTL / "sx1278_controller_pkg.vhd",
            RTL / "command_acceptance_validator.vhd",
            RTL / "command_decoder.vhd",
            *SX1278_RTL[1:],
            RTL / "uart_response_serializer.vhd",
            RTL / "uart_rx_serializer.vhd",
            RTL / "uart_tx_master.vhd",
            RTL / "led_status_controller.vhd",
            RTL / "lora_command_fpga_manager.vhd",
            VERIFY / "tests" / "LORA_UART" / "hdl" /
            "lora_top_verification_wrapper.vhd",
        ],
        "parameters": {
            "CLK_FREQ_HZ": 10_000_000,
            "SPI_FREQ_HZ": 1_000_000,
            "UART_BAUDRATE": 100_000,
            "MAX_DATA_BYTES": 50,
        },
    },
}


def test_cases(name):
    suite = SUITES[name]
    testbenches = sorted(suite["test_dir"].glob("testbench*.py"))
    modules = [path.stem for path in testbenches]
    if not modules:
        modules = [suite["module"]]
    return [(module.removeprefix("testbench-").removeprefix("testbench_"),
             module) for module in modules]


def list_tests():
    print("Tests disponibles:")
    for suite_name in SUITES:
        for case_name, _ in test_cases(suite_name):
            print(f"  {suite_name}/{case_name}")


def run_suite(name, selected_case=None):
    from cocotb_test.simulator import run

    suite = SUITES[name]
    cases = test_cases(name)
    if selected_case is not None:
        cases = [(case_name, module) for case_name, module in cases
                 if case_name == selected_case]
        if not cases:
            available = ", ".join(case for case, _ in test_cases(name))
            raise ValueError(
                f"El test '{name}/{selected_case}' no existe. "
                f"Casos disponibles en {name}: {available}")

    results = []
    for case_name, module in cases:
        build = VERIFY / "sim_build" / name / case_name
        print(f"--- {name}: {case_name}", flush=True)
        passed = True
        try:
            run(
                simulator="ghdl",
                vhdl_sources=[str(path) for path in suite["sources"]],
                toplevel=suite["top"],
                module=module,
                parameters=suite["parameters"],
                compile_args=["--std=08", "--ieee=synopsys"],
                sim_args=["--ieee-asserts=disable"],
                python_search=[str(suite["test_dir"]), str(VERIFY)],
                sim_build=str(build),
                waves=True,
            )
        except (Exception, SystemExit) as error:
            passed = False
            print(f"Fallo {name}/{case_name}: {error}", flush=True)

        wave = build / f"{suite['top']}.ghw"
        if wave.exists():
            destination = VERIFY / "waveforms" / name / f"{case_name}.ghw"
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(wave, destination)

        results.append((f"{name}/{case_name}", passed))

    return results


def print_summary(results):
    """Muestra un resultado compacto y conserva un estado útil para CI."""
    print("\n=== Resumen de verificacion ===", flush=True)
    for test_name, passed in results:
        status = "PASSED" if passed else "FAILED"
        print(f"{test_name:<42} {status}", flush=True)

    passed_count = sum(passed for _, passed in results)
    failed_count = len(results) - passed_count
    print(f"\nTotal: {len(results)} | PASSED: {passed_count} | "
          f"FAILED: {failed_count}", flush=True)
    return failed_count


def main():
    parser = argparse.ArgumentParser(description="Verificacion Cocotb del LoRa FPGA")
    parser.add_argument("suite", choices=["all", *SUITES], nargs="?",
                        default="all")
    parser.add_argument("--list", action="store_true",
                        help="Lista todos los tests disponibles")
    parser.add_argument("--test", metavar="SUITE/CASO",
                        help="Ejecuta un unico test, por ejemplo uart/00-tx-byte")
    args = parser.parse_args()
    os.environ.setdefault("PYTHONPATH", str(VERIFY))

    if args.list:
        list_tests()
        return

    if args.test:
        try:
            suite_name, case_name = args.test.split("/", 1)
            if suite_name not in SUITES:
                raise ValueError(f"La suite '{suite_name}' no existe")
            print(f"\n=== Ejecutando {suite_name}/{case_name} ===", flush=True)
            results = run_suite(suite_name, case_name)
        except ValueError as error:
            parser.error(f"{error}. Use --list para consultar los nombres")
        raise SystemExit(1 if print_summary(results) else 0)

    names = SUITES if args.suite == "all" else (args.suite,)
    results = []
    for name in names:
        print(f"\n=== Ejecutando suite {name} ===", flush=True)
        results.extend(run_suite(name))

    raise SystemExit(1 if print_summary(results) else 0)


if __name__ == "__main__":
    main()
