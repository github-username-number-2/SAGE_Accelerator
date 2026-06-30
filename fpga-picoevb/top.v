/*
 * Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

`timescale 1ns / 1ps

module top(
    input perst_n,
    output clkreq_n,
    input refclk_p,
    input refclk_n,
    input per0_p,
    input per0_n,
    output pet0_p,
    output pet0_n,
    output [2:0] leds,
    inout [3:0] iocon
);
    assign clkreq_n = 1'b0;

    wire sys_clk;
    IBUFDS_GTE2 pcie_clk_ibuf(
        .I(refclk_p),
        .IB(refclk_n),
        .CEB(1'b0),
        .O(sys_clk),
        .ODIV2()
    );

    wire user_lnk_up;
    wire axi_aclk;
    wire axi_aresetn;
    wire usr_irq_req;
    wire usr_irq_ack;
    wire msi_enable;
    wire [2:0] msi_vector_width;
    wire m_axi_awready;
    wire m_axi_wready;
    wire [1:0] m_axi_bid;
    wire [1:0] m_axi_bresp;
    wire m_axi_bvalid;
    wire m_axi_arready;
    wire [1:0] m_axi_rid;
    wire [63:0] m_axi_rdata;
    wire [1:0] m_axi_rresp;
    wire m_axi_rlast;
    wire m_axi_rvalid;
    wire [1:0] m_axi_awid;
    wire [63:0] m_axi_awaddr;
    wire [7:0] m_axi_awlen;
    wire [2:0] m_axi_awsize;
    wire [1:0] m_axi_awburst;
    wire [2:0] m_axi_awprot;
    wire m_axi_awvalid;
    wire m_axi_awlock;
    wire [3:0] m_axi_awcache;
    wire [63:0] m_axi_wdata;
    wire [7:0] m_axi_wstrb;
    wire m_axi_wlast;
    wire m_axi_wvalid;
    wire m_axi_bready;
    wire [1:0] m_axi_arid;
    wire [63:0] m_axi_araddr;
    wire [7:0] m_axi_arlen;
    wire [2:0] m_axi_arsize;
    wire [1:0] m_axi_arburst;
    wire [2:0] m_axi_arprot;
    wire m_axi_arvalid;
    wire m_axi_arlock;
    wire [3:0] m_axi_arcache;
    wire m_axi_rready;
    wire [31:0] m_axil_awaddr;
    wire [2:0] m_axil_awprot;
    wire m_axil_awvalid;
    wire m_axil_awready;
    wire [31:0] m_axil_wdata;
    wire [3:0] m_axil_wstrb;
    wire m_axil_wvalid;
    wire m_axil_wready;
    wire m_axil_bvalid;
    wire [1:0] m_axil_bresp;
    wire m_axil_bready;
    wire [31:0] m_axil_araddr;
    wire [2:0] m_axil_arprot;
    wire m_axil_arvalid;
    wire m_axil_arready;
    wire [31:0] m_axil_rdata;
    wire [1:0] m_axil_rresp;
    wire m_axil_rvalid;
    wire m_axil_rready;
    xdma_0 xdma(
        .sys_clk(sys_clk),
        .sys_rst_n(perst_n),
        .user_lnk_up(user_lnk_up),
        .pci_exp_rxp(per0_p),
        .pci_exp_rxn(per0_n),
        .pci_exp_txp(pet0_p),
        .pci_exp_txn(pet0_n),
        .axi_aclk(axi_aclk),
        .axi_aresetn(axi_aresetn),
        .usr_irq_req(usr_irq_req),
        .usr_irq_ack(usr_irq_ack),
        .msi_enable(msi_enable),
        .msi_vector_width(msi_vector_width),
        .m_axi_awready(m_axi_awready),
        .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_rready(m_axi_rready),
        .m_axil_awaddr(m_axil_awaddr),
        .m_axil_awprot(m_axil_awprot),
        .m_axil_awvalid(m_axil_awvalid),
        .m_axil_awready(m_axil_awready),
        .m_axil_wdata(m_axil_wdata),
        .m_axil_wstrb(m_axil_wstrb),
        .m_axil_wvalid(m_axil_wvalid),
        .m_axil_wready(m_axil_wready),
        .m_axil_bvalid(m_axil_bvalid),
        .m_axil_bresp(m_axil_bresp),
        .m_axil_bready(m_axil_bready),
        .m_axil_araddr(m_axil_araddr),
        .m_axil_arprot(m_axil_arprot),
        .m_axil_arvalid(m_axil_arvalid),
        .m_axil_arready(m_axil_arready),
        .m_axil_rdata(m_axil_rdata),
        .m_axil_rresp(m_axil_rresp),
        .m_axil_rvalid(m_axil_rvalid),
        .m_axil_rready(m_axil_rready)
    );

    wire bram_rst_a;
    wire bram_clk_a;
    wire bram_en_a;
    wire [7:0] bram_we_a;
    wire [15:0] bram_addr_a;
    wire [63:0] bram_wrdata_a;
    wire [63:0] bram_rddata_a;
    axi_bram_ctrl_0 axi_bram_ctrl(
        .s_axi_aclk(axi_aclk),
        .s_axi_aresetn(axi_aresetn),
        .s_axi_awid(m_axi_awid),
        .s_axi_awaddr(m_axi_awaddr[15:0]),
        .s_axi_awlen(m_axi_awlen),
        .s_axi_awsize(m_axi_awsize),
        .s_axi_awburst(m_axi_awburst),
        .s_axi_awlock(m_axi_awlock),
        .s_axi_awcache(m_axi_awcache),
        .s_axi_awprot(m_axi_awprot),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),
        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wlast(m_axi_wlast),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),
        .s_axi_bid(m_axi_bid),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),
        .s_axi_arid(m_axi_arid),
        .s_axi_araddr(m_axi_araddr[15:0]),
        .s_axi_arlen(m_axi_arlen),
        .s_axi_arsize(m_axi_arsize),
        .s_axi_arburst(m_axi_arburst),
        .s_axi_arlock(m_axi_arlock),
        .s_axi_arcache(m_axi_arcache),
        .s_axi_arprot(m_axi_arprot),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),
        .s_axi_rid(m_axi_rid),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rlast(m_axi_rlast),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready),
        .bram_rst_a(bram_rst_a),
        .bram_clk_a(bram_clk_a),
        .bram_en_a(bram_en_a),
        .bram_we_a(bram_we_a),
        .bram_addr_a(bram_addr_a),
        .bram_wrdata_a(bram_wrdata_a),
        .bram_rddata_a(bram_rddata_a)
    );

    blk_mem_gen_0 axi_bram(
        .clka(bram_clk_a),
        .rsta(bram_rst_a),
        .ena(bram_en_a),
        .wea(bram_we_a),
        .addra(bram_addr_a[15:3]),
        .dina(bram_wrdata_a),
        .douta(bram_rddata_a),
        .rsta_busy()
    );

    wire [3:0] iocon_buf_i;
    wire [3:0] iocon_buf_o;
    wire [3:0] iocon_buf_t;
    genvar i;
    generate
        for (i = 0; i < 4 ; i = i + 1) begin
            IOBUF iocon_buf(
                .I(iocon_buf_i[i]),
                .IO(iocon[i]),
                .O(iocon_buf_o[i]),
                .T(iocon_buf_t[i])
            );
        end
    endgenerate
    
    // ============================================================
    // AXI-Lite address decoder
    //   0x0000_0000 - 0x0000_FFFF : GPIO
    //   0x0001_0000 - 0x0001_FFFF : Adder
    // ============================================================
 wire [31:0] gpio_awaddr;
    wire [2:0]  gpio_awprot;
    wire        gpio_awvalid;
    wire        gpio_awready;
    wire [31:0] gpio_wdata;
    wire [3:0]  gpio_wstrb;
    wire        gpio_wvalid;
    wire        gpio_wready;
    wire [1:0]  gpio_bresp;
    wire        gpio_bvalid;
    wire        gpio_bready;
    wire [31:0] gpio_araddr;
    wire [2:0]  gpio_arprot;
    wire        gpio_arvalid;
    wire        gpio_arready;
    wire [31:0] gpio_rdata;
    wire [1:0]  gpio_rresp;
    wire        gpio_rvalid;
    wire        gpio_rready;

    wire [31:0] adder_awaddr;
    wire [2:0]  adder_awprot;
    wire        adder_awvalid;
    wire        adder_awready;
    wire [31:0] adder_wdata;
    wire [3:0]  adder_wstrb;
    wire        adder_wvalid;
    wire        adder_wready;
    wire [1:0]  adder_bresp;
    wire        adder_bvalid;
    wire        adder_bready;
    wire [31:0] adder_araddr;
    wire [2:0]  adder_arprot;
    wire        adder_arvalid;
    wire        adder_arready;
    wire [31:0] adder_rdata;
    wire [1:0]  adder_rresp;
    wire        adder_rvalid;
    wire        adder_rready;

    axil_1x2_decoder axil_decoder (
    .aclk(axi_aclk),
    .aresetn(axi_aresetn),

    .s_awaddr(m_axil_awaddr),
    .s_awprot(m_axil_awprot),
    .s_awvalid(m_axil_awvalid),
    .s_awready(m_axil_awready),

    .s_wdata(m_axil_wdata),
    .s_wstrb(m_axil_wstrb),
    .s_wvalid(m_axil_wvalid),
    .s_wready(m_axil_wready),

    .s_bresp(m_axil_bresp),
    .s_bvalid(m_axil_bvalid),
    .s_bready(m_axil_bready),

    .s_araddr(m_axil_araddr),
    .s_arprot(m_axil_arprot),
    .s_arvalid(m_axil_arvalid),
    .s_arready(m_axil_arready),

    .s_rdata(m_axil_rdata),
    .s_rresp(m_axil_rresp),
    .s_rvalid(m_axil_rvalid),
    .s_rready(m_axil_rready),

    .m0_awaddr(gpio_awaddr),
    .m0_awprot(gpio_awprot),
    .m0_awvalid(gpio_awvalid),
    .m0_awready(gpio_awready),
    .m0_wdata(gpio_wdata),
    .m0_wstrb(gpio_wstrb),
    .m0_wvalid(gpio_wvalid),
    .m0_wready(gpio_wready),
    .m0_bresp(gpio_bresp),
    .m0_bvalid(gpio_bvalid),
    .m0_bready(gpio_bready),
    .m0_araddr(gpio_araddr),
    .m0_arprot(gpio_arprot),
    .m0_arvalid(gpio_arvalid),
    .m0_arready(gpio_arready),
    .m0_rdata(gpio_rdata),
    .m0_rresp(gpio_rresp),
    .m0_rvalid(gpio_rvalid),
    .m0_rready(gpio_rready),

    .m1_awaddr(adder_awaddr),
    .m1_awprot(adder_awprot),
    .m1_awvalid(adder_awvalid),
    .m1_awready(adder_awready),
    .m1_wdata(adder_wdata),
    .m1_wstrb(adder_wstrb),
    .m1_wvalid(adder_wvalid),
    .m1_wready(adder_wready),
    .m1_bresp(adder_bresp),
    .m1_bvalid(adder_bvalid),
    .m1_bready(adder_bready),
    .m1_araddr(adder_araddr),
    .m1_arprot(adder_arprot),
    .m1_arvalid(adder_arvalid),
    .m1_arready(adder_arready),
    .m1_rdata(adder_rdata),
    .m1_rresp(adder_rresp),
    .m1_rvalid(adder_rvalid),
    .m1_rready(adder_rready)
);

    axi_gpio_0 axil_gpios(
        .s_axi_aclk(axi_aclk),
        .s_axi_aresetn(axi_aresetn),

        .s_axi_awaddr(gpio_awaddr[8:0]),
        .s_axi_awvalid(gpio_awvalid),
        .s_axi_awready(gpio_awready),

        .s_axi_wdata(gpio_wdata),
        .s_axi_wstrb(gpio_wstrb),
        .s_axi_wvalid(gpio_wvalid),
        .s_axi_wready(gpio_wready),

        .s_axi_bresp(gpio_bresp),
        .s_axi_bvalid(gpio_bvalid),
        .s_axi_bready(gpio_bready),

        .s_axi_araddr(gpio_araddr[8:0]),
        .s_axi_arvalid(gpio_arvalid),
        .s_axi_arready(gpio_arready),

        .s_axi_rdata(gpio_rdata),
        .s_axi_rresp(gpio_rresp),
        .s_axi_rvalid(gpio_rvalid),
        .s_axi_rready(gpio_rready),

        .ip2intc_irpt(usr_irq_req),
        .gpio_io_o(leds),
        .gpio2_io_i(iocon_buf_o),
        .gpio2_io_o(iocon_buf_i),
        .gpio2_io_t(iocon_buf_t)
    );

    //wire [31:0] adder_result;

    axi_lite_adder axil_adder (
        .S_AXI_ACLK(axi_aclk),
        .S_AXI_ARESETN(axi_aresetn),

        .S_AXI_AWADDR(adder_awaddr[3:0]),
        .S_AXI_AWVALID(adder_awvalid),
        .S_AXI_AWREADY(adder_awready),

        .S_AXI_WDATA(adder_wdata),
        .S_AXI_WSTRB(adder_wstrb),
        .S_AXI_WVALID(adder_wvalid),
        .S_AXI_WREADY(adder_wready),

        .S_AXI_BRESP(adder_bresp),
        .S_AXI_BVALID(adder_bvalid),
        .S_AXI_BREADY(adder_bready),

        .S_AXI_ARADDR(adder_araddr[3:0]),
        .S_AXI_ARVALID(adder_arvalid),
        .S_AXI_ARREADY(adder_arready),

        .S_AXI_RDATA(adder_rdata),
        .S_AXI_RRESP(adder_rresp),
        .S_AXI_RVALID(adder_rvalid),
        .S_AXI_RREADY(adder_rready)

        //.result_out(adder_result)
    );

endmodule


    module axil_1x2_decoder (
    input wire        aclk,
    input wire        aresetn,

    input wire [31:0] s_awaddr,
    input wire [2:0]  s_awprot,
    input wire        s_awvalid,
    output reg        s_awready,

    input wire [31:0] s_wdata,
    input wire [3:0]  s_wstrb,
    input wire        s_wvalid,
    output reg        s_wready,

    output wire [1:0] s_bresp,
    output wire       s_bvalid,
    input wire        s_bready,

    input wire [31:0] s_araddr,
    input wire [2:0]  s_arprot,
    input wire        s_arvalid,
    output wire       s_arready,

    output wire [31:0] s_rdata,
    output wire [1:0]  s_rresp,
    output wire        s_rvalid,
    input wire         s_rready,

    output wire [31:0] m0_awaddr,
    output wire [2:0]  m0_awprot,
    output wire        m0_awvalid,
    input wire         m0_awready,

    output wire [31:0] m0_wdata,
    output wire [3:0]  m0_wstrb,
    output wire        m0_wvalid,
    input wire         m0_wready,

    input wire [1:0]   m0_bresp,
    input wire         m0_bvalid,
    output wire        m0_bready,

    output wire [31:0] m0_araddr,
    output wire [2:0]  m0_arprot,
    output wire        m0_arvalid,
    input wire         m0_arready,

    input wire [31:0]  m0_rdata,
    input wire [1:0]   m0_rresp,
    input wire         m0_rvalid,
    output wire        m0_rready,

    output wire [31:0] m1_awaddr,
    output wire [2:0]  m1_awprot,
    output wire        m1_awvalid,
    input wire         m1_awready,

    output wire [31:0] m1_wdata,
    output wire [3:0]  m1_wstrb,
    output wire        m1_wvalid,
    input wire         m1_wready,

    input wire [1:0]   m1_bresp,
    input wire         m1_bvalid,
    output wire        m1_bready,

    output wire [31:0] m1_araddr,
    output wire [2:0]  m1_arprot,
    output wire        m1_arvalid,
    input wire         m1_arready,

    input wire [31:0]  m1_rdata,
    input wire [1:0]   m1_rresp,
    input wire         m1_rvalid,
    output wire        m1_rready
);

    // Address map inside BAR0:
    //   addr[8] = 0 -> GPIO   base 0x000
    //   addr[8] = 1 -> Adder  base 0x100
    wire wr_sel_now = s_awaddr[8];
    wire rd_sel_now = s_araddr[8];

    // ============================================================
    // Write channel buffering
    // AXI-Lite AW and W may arrive independently, so buffer both.
    // Then send one combined AW/W transaction to selected slave.
    // ============================================================

    reg        aw_buf_valid;
    reg [31:0] aw_buf_addr;
    reg [2:0]  aw_buf_prot;
    reg        aw_buf_sel;

    reg        w_buf_valid;
    reg [31:0] w_buf_data;
    reg [3:0]  w_buf_strb;

    reg        wr_resp_sel;
    reg        wr_resp_pending;

    wire have_write_req = aw_buf_valid && w_buf_valid && !wr_resp_pending;

    wire target0_write_ready = m0_awready && m0_wready;
    wire target1_write_ready = m1_awready && m1_wready;

    wire write_to_m0 = have_write_req && (aw_buf_sel == 1'b0);
    wire write_to_m1 = have_write_req && (aw_buf_sel == 1'b1);

    wire write_m0_fire = write_to_m0 && target0_write_ready;
    wire write_m1_fire = write_to_m1 && target1_write_ready;
    wire write_fire    = write_m0_fire || write_m1_fire;

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_awready       <= 1'b0;
            s_wready        <= 1'b0;

            aw_buf_valid    <= 1'b0;
            aw_buf_addr     <= 32'd0;
            aw_buf_prot     <= 3'd0;
            aw_buf_sel      <= 1'b0;

            w_buf_valid     <= 1'b0;
            w_buf_data      <= 32'd0;
            w_buf_strb      <= 4'd0;

            wr_resp_sel     <= 1'b0;
            wr_resp_pending <= 1'b0;
        end else begin
            s_awready <= 1'b0;
            s_wready  <= 1'b0;

            // Accept AW into buffer
            if (!aw_buf_valid && s_awvalid) begin
                s_awready    <= 1'b1;
                aw_buf_valid <= 1'b1;
                aw_buf_addr  <= s_awaddr;
                aw_buf_prot  <= s_awprot;
                aw_buf_sel   <= wr_sel_now;
            end

            // Accept W into buffer
            if (!w_buf_valid && s_wvalid) begin
                s_wready    <= 1'b1;
                w_buf_valid <= 1'b1;
                w_buf_data  <= s_wdata;
                w_buf_strb  <= s_wstrb;
            end

            // Downstream accepted combined AW/W
            if (write_fire) begin
                aw_buf_valid    <= 1'b0;
                w_buf_valid     <= 1'b0;
                wr_resp_sel     <= aw_buf_sel;
                wr_resp_pending <= 1'b1;
            end

            // Upstream accepted B response
            if (s_bvalid && s_bready) begin
                wr_resp_pending <= 1'b0;
            end
        end
    end

    assign m0_awaddr  = aw_buf_addr;
    assign m0_awprot  = aw_buf_prot;
    assign m0_awvalid = write_to_m0;

    assign m0_wdata   = w_buf_data;
    assign m0_wstrb   = w_buf_strb;
    assign m0_wvalid  = write_to_m0;

    assign m1_awaddr  = aw_buf_addr;
    assign m1_awprot  = aw_buf_prot;
    assign m1_awvalid = write_to_m1;

    assign m1_wdata   = w_buf_data;
    assign m1_wstrb   = w_buf_strb;
    assign m1_wvalid  = write_to_m1;

    assign s_bvalid   = (wr_resp_sel == 1'b0) ? m0_bvalid : m1_bvalid;
    assign s_bresp    = (wr_resp_sel == 1'b0) ? m0_bresp  : m1_bresp;

    assign m0_bready  = s_bready && wr_resp_pending && (wr_resp_sel == 1'b0);
    assign m1_bready  = s_bready && wr_resp_pending && (wr_resp_sel == 1'b1);

    // ============================================================
    // Read channel
    // Latch selected target at AR handshake.
    // Use latched rd_resp_sel during R response.
    // ============================================================

    reg rd_resp_sel;
    reg rd_resp_pending;

    wire read_to_m0 = s_arvalid && (rd_sel_now == 1'b0) && !rd_resp_pending;
    wire read_to_m1 = s_arvalid && (rd_sel_now == 1'b1) && !rd_resp_pending;

    assign m0_araddr  = s_araddr;
    assign m0_arprot  = s_arprot;
    assign m0_arvalid = read_to_m0;

    assign m1_araddr  = s_araddr;
    assign m1_arprot  = s_arprot;
    assign m1_arvalid = read_to_m1;

    assign s_arready  = (rd_sel_now == 1'b0) ? (m0_arready && !rd_resp_pending)
                                             : (m1_arready && !rd_resp_pending);

    wire ar_fire = s_arvalid && s_arready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            rd_resp_sel     <= 1'b0;
            rd_resp_pending <= 1'b0;
        end else begin
            if (ar_fire) begin
                rd_resp_sel     <= rd_sel_now;
                rd_resp_pending <= 1'b1;
            end else if (s_rvalid && s_rready) begin
                rd_resp_pending <= 1'b0;
            end
        end
    end

    assign s_rvalid  = (rd_resp_sel == 1'b0) ? m0_rvalid : m1_rvalid;
    assign s_rresp   = (rd_resp_sel == 1'b0) ? m0_rresp  : m1_rresp;
    assign s_rdata   = (rd_resp_sel == 1'b0) ? m0_rdata  : m1_rdata;

    assign m0_rready = s_rready && rd_resp_pending && (rd_resp_sel == 1'b0);
    assign m1_rready = s_rready && rd_resp_pending && (rd_resp_sel == 1'b1);

endmodule

module axi_lite_adder #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)(
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,

    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire S_AXI_AWVALID,
    output reg S_AXI_AWREADY,

    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire S_AXI_WVALID,
    output reg S_AXI_WREADY,

    output reg [1:0] S_AXI_BRESP,
    output reg S_AXI_BVALID,
    input wire S_AXI_BREADY,

    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire S_AXI_ARVALID,
    output reg S_AXI_ARREADY,

    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [1:0] S_AXI_RRESP,
    output reg S_AXI_RVALID,
    input wire S_AXI_RREADY
);

    reg [31:0] reg0_a;
    reg [31:0] reg1_b;
    reg [31:0] reg3_ctrl;

    reg aw_holding;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;

    reg w_holding;
    reg [31:0] wdata_hold;
    reg [3:0]  wstrb_hold;

    integer byte_index;

    wire do_write = aw_holding && w_holding && !S_AXI_BVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            S_AXI_BVALID  <= 1'b0;

            S_AXI_ARREADY <= 1'b0;
            S_AXI_RDATA   <= 32'd0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RVALID  <= 1'b0;

            reg0_a        <= 32'd0;
            reg1_b        <= 32'd0;
            reg3_ctrl     <= 32'd0;

            aw_holding    <= 1'b0;
            awaddr_hold   <= {C_S_AXI_ADDR_WIDTH{1'b0}};

            w_holding     <= 1'b0;
            wdata_hold    <= 32'd0;
            wstrb_hold    <= 4'd0;
        end else begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_ARREADY <= 1'b0;

            // -------------------------------
            // Accept AW independently
            // -------------------------------
            if (!aw_holding && !S_AXI_BVALID && S_AXI_AWVALID) begin
                S_AXI_AWREADY <= 1'b1;
                aw_holding    <= 1'b1;
                awaddr_hold   <= S_AXI_AWADDR;
            end

            // -------------------------------
            // Accept W independently
            // -------------------------------
            if (!w_holding && !S_AXI_BVALID && S_AXI_WVALID) begin
                S_AXI_WREADY <= 1'b1;
                w_holding    <= 1'b1;
                wdata_hold   <= S_AXI_WDATA;
                wstrb_hold   <= S_AXI_WSTRB;
            end

            // -------------------------------
            // Perform write when both AW and W are captured
            // -------------------------------
            if (do_write) begin
                case (awaddr_hold[3:2])
                    2'b00: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (wstrb_hold[byte_index])
                                reg0_a[byte_index*8 +: 8] <= wdata_hold[byte_index*8 +: 8];
                        end
                    end

                    2'b01: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (wstrb_hold[byte_index])
                                reg1_b[byte_index*8 +: 8] <= wdata_hold[byte_index*8 +: 8];
                        end
                    end

                    2'b10: begin
                        // result is read-only
                    end

                    2'b11: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (wstrb_hold[byte_index])
                                reg3_ctrl[byte_index*8 +: 8] <= wdata_hold[byte_index*8 +: 8];
                        end
                    end
                endcase

                aw_holding   <= 1'b0;
                w_holding    <= 1'b0;

                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            // -------------------------------
            // Read channel
            // -------------------------------
            if (!S_AXI_RVALID && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b1;

                
                case (S_AXI_ARADDR[3:2])
                    2'b00: S_AXI_RDATA <= reg0_a;
                    2'b01: S_AXI_RDATA <= reg1_b;
                    2'b10: S_AXI_RDATA <= reg0_a + reg1_b;
                    2'b11: S_AXI_RDATA <= reg3_ctrl;
                    default: S_AXI_RDATA <= 32'h0e0e_f0f0;
                endcase

                  
                S_AXI_RRESP  <= 2'b00;
                S_AXI_RVALID <= 1'b1;
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule

//module axi_lite_adder #(
//    parameter integer C_S_AXI_DATA_WIDTH = 32,
//    parameter integer C_S_AXI_ADDR_WIDTH = 4
//)(
//    input wire S_AXI_ACLK,
//    input wire S_AXI_ARESETN,

//    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
//    input wire S_AXI_AWVALID,
//    output reg S_AXI_AWREADY,

//    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
//    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
//    input wire S_AXI_WVALID,
//    output reg S_AXI_WREADY,

//    output reg [1:0] S_AXI_BRESP,
//    output reg S_AXI_BVALID,
//    input wire S_AXI_BREADY,

//    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
//    input wire S_AXI_ARVALID,
//    output reg S_AXI_ARREADY,

//    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
//    output reg [1:0] S_AXI_RRESP,
//    output reg S_AXI_RVALID,
//    input wire S_AXI_RREADY

//    //output wire [31:0] result_out
//);

//    reg [31:0] reg0_a;
//    reg [31:0] reg1_b;
//    reg [31:0] reg3_ctrl;

//    //wire [31:0] reg2_result;
//    //assign reg2_result = reg0_a + reg1_b;
//    //assign result_out = reg2_result;

//    //wire write_fire = S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY  && S_AXI_WVALID;
//    wire write_fire = !S_AXI_BVALID && S_AXI_AWVALID && S_AXI_WVALID;
//    //wire read_fire  = S_AXI_ARREADY && S_AXI_ARVALID;
//    wire read_fire = !S_AXI_RVALID && S_AXI_ARVALID;

//    integer byte_index;

//    always @(posedge S_AXI_ACLK) begin
//        if (!S_AXI_ARESETN) begin
//            S_AXI_AWREADY <= 1'b0;
//            S_AXI_WREADY  <= 1'b0;
//            S_AXI_BRESP   <= 2'b00;
//            S_AXI_BVALID  <= 1'b0;

//            S_AXI_ARREADY <= 1'b0;
//            S_AXI_RDATA   <= 32'd0;
//            S_AXI_RRESP   <= 2'b00;
//            S_AXI_RVALID  <= 1'b0;

//            reg0_a        <= 32'd0;
//            reg1_b        <= 32'd0;
//            reg3_ctrl     <= 32'd0;
//        end else begin
//            S_AXI_AWREADY <= 1'b0;
//            S_AXI_WREADY  <= 1'b0;
//            S_AXI_ARREADY <= 1'b0;

//            // if (!S_AXI_BVALID && !S_AXI_AWREADY && !S_AXI_WREADY &&
//            //     S_AXI_AWVALID && S_AXI_WVALID) begin
//            //     S_AXI_AWREADY <= 1'b1;
//            //     S_AXI_WREADY  <= 1'b1;
//            // end

//            if (write_fire) begin
//                S_AXI_AWREADY <= 1'b1;
//                S_AXI_WREADY  <= 1'b1;
//                case (S_AXI_AWADDR[3:2])
//                    2'b00: begin
//                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
//                            if (S_AXI_WSTRB[byte_index]) begin
//                                reg0_a[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
//                            end
//                        end
//                    end

//                    2'b01: begin
//                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
//                            if (S_AXI_WSTRB[byte_index]) begin
//                                reg1_b[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
//                            end
//                        end
//                    end

//                    2'b10: begin
//                        // reg2 is read-only result. Ignore writes.
//                    end

//                    2'b11: begin
//                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
//                            if (S_AXI_WSTRB[byte_index]) begin
//                                reg3_ctrl[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
//                            end
//                        end
//                    end
//                endcase

//                S_AXI_BVALID <= 1'b1;
//                S_AXI_BRESP  <= 2'b00;
//            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
//                S_AXI_BVALID <= 1'b0;
//            end

//            // if (!S_AXI_RVALID && !S_AXI_ARREADY && S_AXI_ARVALID) begin
//            //     S_AXI_ARREADY <= 1'b1;
//            // end

//            if (read_fire) begin
//                S_AXI_ARREADY <= 1'b1;
//                case (S_AXI_ARADDR[3:2])
//                    2'b00: S_AXI_RDATA <= reg0_a;
//                    2'b01: S_AXI_RDATA <= reg1_b;
//                    2'b10: S_AXI_RDATA <= reg0_a + reg1_b;
//                    2'b11: S_AXI_RDATA <= reg3_ctrl;
//                    default: S_AXI_RDATA <= 32'h0000_0000;
//                endcase
////                    case (S_AXI_ARADDR[3:2])  
////                        2'b00: S_AXI_RDATA <= 32'haaaa_0000 | reg0_a[15:0]; // debug
////                        2'b01: S_AXI_RDATA <= 32'hbbbb_0000 | reg1_b[15:0];
////                        2'b10: S_AXI_RDATA <= 32'hcccc_0000 | (reg0_a + reg1_b);
////                        2'b11: S_AXI_RDATA <= 32'hdddd_0000 | reg3_ctrl[15:0];
////                        default: S_AXI_RDATA <= 32'heeee_eeee;
////                    endcase

//                S_AXI_RRESP  <= 2'b00;
//                S_AXI_RVALID <= 1'b1;
//            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
//                S_AXI_RVALID <= 1'b0;
//            end
//        end
//    end

//endmodule

