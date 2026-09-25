# Hardware/Firmware Root of Trust (RoT)

> An open-source, highly secure Root of Trust framework engineered to provide an immutable foundation for secure boot, cryptographic validation, and chain-of-trust execution in embedded and custom digital systems.

---

## 📋 Table of Contents
* [Overview](#-overview)
* [System Architecture & Boot Flow](#-system-architecture--boot-flow)
* [Technical Specifications & Key Features](#-technical-specifications--key-features)
* [Repository Structure](#-repository-structure)
* [Getting Started](#-getting-started)
  * [Prerequisites & Dependencies](#prerequisites--dependencies)
  * [Cloning and Setup](#cloning-and-setup)
* [Building, Compiling & Simulation](#-building-compiling--simulation)
* [Cryptographic & Signing Workflow](#-cryptographic--signing-workflow)
* [Testing, Verification & Testbenches](#-testing-verification--testbenches)
* [Security Considerations & Threat Mitigation](#-security-considerations--threat-mitigation)
* [Contributing](#-contributing)
* [License](#-license)

---

## 🔍 Overview

The **Root of Trust (RoT)** is the most critical security subsystem in any modern computing or embedded device. Because it cannot be updated or modified once deployed, it serves as the ultimate anchor for system integrity. 

This repository provides a comprehensive reference implementation split between low-level hardware design modules and secure firmware components. It ensures that every stage of execution—from initial power-on reset (POR) up to the operating system or application layer—is cryptographically verified against tampering, unauthorized modifications, and rollback attacks.

---

## 🔄 System Architecture & Boot Flow

The system follows a strict, sequential **Chain of Trust**. Each layer validates the cryptographic signature and integrity of the subsequent layer before transferring program counter control.

```text
+---------------------------------------------------------------+
|                STAGE 0: ROOT OF TRUST (RoT)                   |
|  - Immutable Boot ROM / Fused Public Keys / Hardware FSM     |
+---------------------------------------------------------------+
                                |
                                v (Verifies ECDSA/RSA Signature)
+---------------------------------------------------------------+
|               STAGE 1: SECONDARY BOOTLOADER                   |
|  - Initializing Peripherals / External Flash Controller       |
+---------------------------------------------------------------+
                                |
                                v (Extends Trust Verification)
+---------------------------------------------------------------+
|               STAGE 2: OPERATING SYSTEM / KERNEL              |
|  - Fully Validated Runtime Environment                        |
+---------------------------------------------------------------+
```

### Boot Sequence Steps:
1. **Power-On Reset (POR):** The processor core awakens and fetches its very first instruction vector directly from the immutable RoT memory space (e.g., internal Mask ROM or write-locked OTP memory).
2. **Hardware State Initialization:** Critical security peripherals, watchdog timers, and secure RAM boundaries are configured.
3. **Image Authentication:** The cryptographic verification engine reads the secondary boot image from external flash, computes its hash (e.g., SHA-256), and verifies the accompanying digital signature against the onboard immutable public key.
4. **Execution Transfer:** 
   * **On Success:** Control is handed over to the secondary bootloader entry point.
   * **On Failure:** The system immediately aborts, locks down critical buses, logs a security fault, or falls back to a secure recovery mode.

---

## ✨ Technical Specifications & Key Features

* **Hardware-Enforced Immutability:** Designed to reside in write-protected storage or hardware fuse arrays to prevent persistent rootkit installation.
* **Robust Cryptographic Engines:** Supports industry-standard algorithms including **SHA-256/SHA-384** for hashing and **ECDSA (secp256r1/ed25519)** or **RSA-3072** for signature verification.
* **Anti-Rollback Protection:** Utilizes monotonic hardware/software counters (stored in secure non-volatile memory) to prevent attackers from flashing older, vulnerable firmware versions.
* **Secure Key Management:** Strict hardware isolation of root public keys, device-unique secret seeds (e.g., PUF interfaces), and cryptographic scratchpads.
* **Side-Channel & Fault Defenses:** Structured pipeline design addressing power analysis and fault-injection attack surface areas.

---

## 📂 Repository Structure

```text
root-of-trust/
├── docs/                   # Architecture specs, security threat models, and flow diagrams
├── rtl/                    # Hardware description files (Verilog / SystemVerilog)
│   ├── core/               # Main RoT state machine and control logic
│   ├── crypto/             # Hardware hash and signature verification accelerators
│   └── memory/             # Secure RAM / ROM controllers and bus wrappers
├── firmware/               # Low-level secure bootloader code (C / Assembly / Rust)
│   ├── bootrom/            # Stage 0 ROM image code
│   └── drivers/            # Cryptographic library bindings and flash drivers
├── scripts/                # Build automation, image signing, and key generation tools
├── tests/                  # Verification testbenches, simulation scripts, and unit tests
└── README.md               # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites & Dependencies
Ensure your development environment has the necessary toolchains installed depending on whether you are compiling the hardware RTL or the embedded firmware:

* **For Hardware (RTL):** 
  * Verilator or ModelSim / QuestaSim for simulation
  * Icarus Verilog (optional for lightweight testbenches)
  * Make / CMake
* **For Firmware & Scripts:**
  * Python 3.10+ (for key generation and image signing automation scripts)
  * OpenSSL or `cryptography` Python package
  * Embedded GNU Toolchain (`arm-none-eabi-gcc` or `riscv64-unknown-elf-gcc`)

### Cloning and Setup
```bash
# Clone the repository recursively to capture any submodules
git clone https://github.com/your-username/root-of-trust.git
cd root-of-trust

# Install Python dependencies for build and signing scripts
pip install -r scripts/requirements.txt
```

---

## ⚙️ Building, Compiling & Simulation

### 1. Generating Test Keys and Signing an Image
Before booting, firmware images must be signed using the private root key matching the public key embedded in the RoT.
```bash
# Generate a test private/public key pair
python scripts/key_gen.py --output keys/

# Sign a binary firmware image
python scripts/sign_image.py --input build/firmware.bin --key keys/private.pem --output build/signed_firmware.bin
```

### 2. Compiling Firmware
```bash
cd firmware/bootrom
make clean && make ARCH=arm
```

---

## 🧪 Testing, Verification & Testbenches

The project includes automated regression tests covering positive boot paths and negative security exception paths:
* **Valid Signature Test:** Ensures seamless handoff when a correctly signed image is presented.
* **Corrupted Image Test:** Injects bit-flips into the binary to confirm that the RoT catches the mismatch and triggers a lock/abort state.
* **Rollback Attack Test:** Attempts to load an image with an older version number to verify that the monotonic counter defense holds.

Run the full verification suite using:
```bash
make test-all
```

---

## 🛡️ Security Considerations & Threat Mitigation

* **Physical Attacks:** Designed with secure bus protocols and memory scrambling interfaces to deter probing and bus-sniffing.
* **Fault Injection (FI):** Critical branch conditions utilize redundant checks and dual-rail logic flags to prevent voltage or clock glitching bypasses.
* **Denial of Service (DoS):** Recovery loops are bounded by hardware watchdog timers to prevent infinite hanging states during authentication failures.

---

## Contributing

Contributions are highly encouraged to improve the cryptographic rigor, expand platform support, or harden verification coverage. 
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/SecureFeature`)
3. Commit your Changes (`git commit -m 'Add secure hardware watchdog timer'`)
4. Push to the Branch (`git origin push feature/SecureFeature`)
5. Open a Pull Request

---
