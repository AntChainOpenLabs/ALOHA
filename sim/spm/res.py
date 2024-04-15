# handle the result of encoder
# 0  0*128 + 1
# 16 16*128 + 1
# 32 32*128 + 1
# 48
# 1
# 17
# 33
# 49
# ...
# 15
# 31
# 47
# 63
n = 8192
m = 128
test_num = 4

lines = []
with open("", 'r') as f:
    lines = f.readlines()
tmp_res = [lines[i:i+n] for i in range(0, len(lines) - 1, n)]
for each_res in tmp_res:
    sim_res = [each_res[i:i+m] for i in range(0, len(each_res), m)]
    res = sim_res[0] + sim_res[4] + sim_res[8] + sim_res[12] + sim_res[16] + sim_res[20] + sim_res[24] + sim_res[28] + sim_res[32] + sim_res[36] + sim_res[40] + sim_res[44] + sim_res[48] + sim_res[52] + sim_res[56] + sim_res[60] + sim_res[1] + sim_res[5] + sim_res[9] + sim_res[13] + sim_res[17] + sim_res[21] + sim_res[25] + sim_res[29] + sim_res[33] + sim_res[37] + sim_res[41] + sim_res[45] + sim_res[49] + sim_res[53] + sim_res[57] + sim_res[61] + sim_res[2] + sim_res[6] + sim_res[10] + sim_res[14] + sim_res[18] + sim_res[22] + sim_res[26] + sim_res[30] + sim_res[34] + sim_res[38] + sim_res[42] + sim_res[46] + sim_res[50] + sim_res[54] + sim_res[58] + sim_res[62] + sim_res[3] + sim_res[7] + sim_res[11] + sim_res[15] + sim_res[19] + sim_res[23] + sim_res[27] + sim_res[31] + sim_res[35] + sim_res[39] + sim_res[43] + sim_res[47] + sim_res[51] + sim_res[55] + sim_res[59] + sim_res[63]

    with open("", 'a') as f:
            f.writelines(res)
