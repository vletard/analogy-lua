
ILAR engine documentation
-------------------------

The ILAR engine (Incremental Learning by Analogical Reasoning) performs direct, indirect and approximate analogical reasoning on textual items.
The system reads examples from the input and output domain parallel bases and uses them to search for analogical patterns to solve.

Check [this paper](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=7814600) for an overview of the principle.
[This one](http://ceur-ws.org/Vol-1815/paper9.pdf) focuses on approximate analogical reasoning.
Extensive information is available in French in [the thesis](https://tel.archives-ouvertes.fr/tel-01532754/document).

Author: Vincent Letard

## Quick usage

```
./ilar.sh -p $KB_PATH/knowledge_base
```

The `knowledge_base.in` and `knowledge_base.out` files are just parallel lists of sentences respectively in the source and target domains.

## Main options

### Deviation

Specifying a positive deviation margin will allow the system to report solutions of approximate analogical patterns.
Specific deviation margins can be specified for searching analogies and solving analogies.
Be careful as computation time may increase a lot with the value of the deviation margin.

### Analogical mode

This option can take four values:

* singletons: deactivate reasoning for testing purpose
* inter: only use direct analogical solving (inter domain)
* intra: only use indirect analogical solving (intra domain)
* both: all analogical reasoning features (default option)

### Time limit

A time limit can be set in seconds that applies for indirect solving only.
This is useful when the knowledge base grow big.
