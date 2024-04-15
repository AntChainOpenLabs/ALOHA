# test data

## Format
- ct = (ct_a, ct_b) 4polys
- ct_a/b(s) are 2 8192-degree polys mod q0, q1;
- order: ct_a(mod q0) | ct_a(mod q1) | ct_b(mod q0) | ct_b(mod q1)

- pt(s) are 2 8192-degree polys
  

## rotate
> ct_before_rotate
> ct_after_rotate

## mulplain
> ct_before_mulplain
> pt_before_mulplain
> ct_after_mulplain

## homadd
> ct_before_homaddct1
> ct_before_homaddct2
> ct_after_homadd

## encode_data
> plaintext_after_encode_fft_mod : encode result before NTT
> pt_after_encode : encode result after NTT