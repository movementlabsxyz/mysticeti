# Mysticeti

[![rustc](https://img.shields.io/badge/rustc-1.72+-blue?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![license](https://img.shields.io/badge/license-Apache-blue.svg?style=flat-square)](LICENSE)

The code in this branch is a prototype of Mysticeti. It supplements the paper [Mysticeti: Low-Latency DAG Consensus with Fast Commit Path](https://arxiv.org/abs/2310.14821) enabling reproducible results. There are no plans to maintain this branch.

## Development

When developing, the analyzer may show errors in files (e.g. in `orchestrator/src/main.rs`). To fix this start code in a nix environment. 

    nix develop
    code .

## Run

For detailed instructions on how to run the project, please refer to the [orchestrator README](orchestrator/README.md).

## License

This software is licensed as [Apache 2.0](LICENSE).
