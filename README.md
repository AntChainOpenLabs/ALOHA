<h1 align="center">ALOHA</h1>
<h4 align="center">ALOHA: Accelerating Leveled Fully Homomorphic Encryption with Cryptography-Specific Architectures</h4>

The __ALOHA__ project is initiated by Alibaba Group and Ant Group's AntChain.

Homomorphic encryption (HE) is a cryptographic technique that allows computations to be performed directly on ciphertext without decryption, which is ideal in privacy-sensitive scenarios, such as cross-organizational collaboration, secure neural network inference (SNNI), and database services. We design RISC-V compatible instructions for accelerating computations on encrypted data, which feature scalable vectorized capability. This project provides several features including,
- Programmable: __ALOHA__ supports the `R` type customized HE RISC-V ISA extension;
- Adaptable: __ALOHA__ can be used as a RISC-V loosely-coupled coprocessor by decoding the `opcode` field, or an HE accelerator mounted on the AXI bus;
- Better performance:  __ALOHA__ utilize the SIMD-style processing and explore dedicated design datapath optimizations for HE operators like `NTT` and `Automorphism`.
- Configurable: The source code supports several micro-architectural parameters on `# lane, etc`. Users can configure the `/src/vp/include/vp_defines.vh` to balance performance and area.

The code in this repository is released by Alibaba DAMO Academy CTL under the MIT License. This distribution is an open-source version of our commercial accelerator and is not ready for production use.

## Table of contents

- [Table of contents](#table-of-contents)
- [Directory structure](#directory-structure)
- [Build guide](#build-guide)
- [License](#license)

## Directory structure

The directory structure is as follows:

* [__sim__](sim): simulation files
* [__src__](src): RTL source files
* [__tv__](tv): test vectors
* [__vivado_prj__](vivado_prj): xilinx vivado simulation project


## Build guide

1. Download and install Vivado IDE following the [official website](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2022-2.html). 

2. Please `git clone` this code repository and open the Vivado project under `/vivado_prj`

3. `/sim/top/top_noaxilite_tb.sv` is the top testbench file with the complete simulation flow, which includes the following tasks:

    * Parsing environment variable parameters
    * Initialization, which includes the following operations:
        * Reading data loaded into DRAM
        * Parsing instruction sequences
        * Initializing AXI VIP
        * Resetting the system.
    * Execution
    * Data Dump 

4. Check the output data with the golden output.


## License

[MIT License](LICENSE)

Please adhere to the Xilinx license requirements, such as the Vivado IDE. This product also contains several third-party components under other open-source licenses.

    src/axi/axi_read_master.sv          BSD-2-Clause        Vitis-Tutorials
    src/axi/axi_write_master.sv         BSD-2-Clause        Vitis-Tutorials
    src/axi/counter.sv                  BSD-2-Clause        Vitis-Tutorials