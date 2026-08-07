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

module top_adapter(
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
    
   
    // CLOCKING: Clock Wizard for FFN 
   
    wire adapter_clk;
    wire locked;
    
    clk_wiz_0 clk_wiz_inst (
        .clk_out1(adapter_clk),      // Clock out ports
        .reset(!axi_aresetn),       //  input reset for clk_wiz
        .locked(locked),           //output locked
        .clk_in1(axi_aclk)     // Clock in ports  125 MHz  
    );
    
    // Safe reset for the adapter domain. wait for AXI reset AND MMCM lock
    wire adapter_arstn_in = axi_aresetn & locked;

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
    // AXI-Lite address decoder (BAR0)
    //   addr[8] = 0 -> 0x000 .. 0x0FF : AXI GPIO 
    //   addr[8] = 1 -> 0x100 .. 0x1FF : FFN adapter
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

    wire [31:0] adapter_awaddr;
    wire [2:0]  adapter_awprot;
    wire        adapter_awvalid;
    wire        adapter_awready;
    wire [31:0] adapter_wdata;
    wire [3:0]  adapter_wstrb;
    wire        adapter_wvalid;
    wire        adapter_wready;
    wire [1:0]  adapter_bresp;
    wire        adapter_bvalid;
    wire        adapter_bready;
    wire [31:0] adapter_araddr;
    wire [2:0]  adapter_arprot;
    wire        adapter_arvalid;
    wire        adapter_arready;
    wire [31:0] adapter_rdata;
    wire [1:0]  adapter_rresp;
    wire        adapter_rvalid;
    wire        adapter_rready;

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

    .m1_awaddr(adapter_awaddr),
    .m1_awprot(adapter_awprot),
    .m1_awvalid(adapter_awvalid),
    .m1_awready(adapter_awready),
    .m1_wdata(adapter_wdata),
    .m1_wstrb(adapter_wstrb),
    .m1_wvalid(adapter_wvalid),
    .m1_wready(adapter_wready),
    .m1_bresp(adapter_bresp),
    .m1_bvalid(adapter_bvalid),
    .m1_bready(adapter_bready),
    .m1_araddr(adapter_araddr),
    .m1_arprot(adapter_arprot),
    .m1_arvalid(adapter_arvalid),
    .m1_arready(adapter_arready),
    .m1_rdata(adapter_rdata),
    .m1_rresp(adapter_rresp),
    .m1_rvalid(adapter_rvalid),
    .m1_rready(adapter_rready)
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

   
    // ============================================================
    // FFN adapter: Verilog AXI4-Lite FSMD front end, which itself
    // instantiates the VHDL core adapter_top (adapter_top.vhd).
	// Includes clock domain crossing 
    // ============================================================
   
    axi_lite_adapter_fsm #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(4)
    ) ffn_adapter (
        .S_AXI_ACLK(axi_aclk),
        .S_AXI_ARESETN(axi_aresetn),
        
        .adapter_clk(adapter_clk), // adapter clk
        .ADAPTER_ARSTN_IN(adapter_arstn_in), // ADAPTER_ARSTN_IN = axi_aresetn & locked;

        .S_AXI_AWADDR(adapter_awaddr[3:0]),
        .S_AXI_AWVALID(adapter_awvalid),
        .S_AXI_AWREADY(adapter_awready),

        .S_AXI_WDATA(adapter_wdata),
        .S_AXI_WSTRB(adapter_wstrb),
        .S_AXI_WVALID(adapter_wvalid),
        .S_AXI_WREADY(adapter_wready),

        .S_AXI_BRESP(adapter_bresp),
        .S_AXI_BVALID(adapter_bvalid),
        .S_AXI_BREADY(adapter_bready),

        .S_AXI_ARADDR(adapter_araddr[3:0]),
        .S_AXI_ARVALID(adapter_arvalid),
        .S_AXI_ARREADY(adapter_arready),

        .S_AXI_RDATA(adapter_rdata),
        .S_AXI_RRESP(adapter_rresp),
        .S_AXI_RVALID(adapter_rvalid),
        .S_AXI_RREADY(adapter_rready)
    );

endmodule


// ================================================================
// axil_1x2_decoder
//
//   addr[9] = 0 -> m0 : AXI GPIO      (BAR0 + 0x000 .. 0x1FF)
//   addr[9] = 1 -> m1 : FFN adapter   (BAR0 + 0x200 .. 0x3FF)
//
// ================================================================

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
    //   addr[8] = 0 -> Target 0  base 0x000 (256 bytes)
    //   addr[8] = 1 -> Target 1  base 0x100 (256 bytes)
    wire wr_sel_now = s_awaddr[8]; // define decoding bit
    wire rd_sel_now = s_araddr[8]; // define decoding bit

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

// ================================================================
// axi_lite_adapter_fsm (WITH INTEGRATED & SAFE CDC)
// ================================================================
module axi_lite_adapter_fsm #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)(
    input wire S_AXI_ACLK,          
    input wire S_AXI_ARESETN,
    
    input wire adapter_clk,        //adapter clk      
    input wire ADAPTER_ARSTN_IN,  // ADAPTER_ARSTN_IN = axi_aresetn & locked;

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

    // -------------------------------------------------------------
    // Register mapping in AXI Clock Domain
    // -------------------------------------------------------------
    reg  [31:0] top_in_data;     // Written by SW (Offset 0x00)
    reg  [31:0] reg_ctrl;        // Written by SW (Offset 0x04)
    wire [31:0] top_out_data;    // Read from HW  (Offset 0x0C)
    reg  [31:0] top_out_data_sync; // converts output data fromm 10 MHz to 100 MHz
    
    wire hw_wdata_read_done;
    wire hw_rdata_ready;

    // AXI specific holding registers
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [31:0]                   wdata_hold;
    reg [3:0]                    wstrb_hold;
    reg                          aw_holding;
    reg                          w_holding;
    integer byte_index;

    wire do_write = aw_holding && w_holding && !S_AXI_BVALID;




    // RESET BRIDGE: SAFELY CROSS RESET TO ADAPTER DOMAIN (w/ ASYNC_REG)

    (* ASYNC_REG = "TRUE" *) reg rst_n_meta, adapter_rst_n;
    
    always @(posedge adapter_clk or negedge ADAPTER_ARSTN_IN) begin
        if (!ADAPTER_ARSTN_IN) begin // ADAPTER_ARSTN_IN = axi_aresetn & locked;
            rst_n_meta    <= 1'b0;
            adapter_rst_n <= 1'b0;
        end else begin
            rst_n_meta    <= 1'b1;
            adapter_rst_n <= rst_n_meta;
        end
    end




    //  Control Signal Sync (100 MHz -> 10 MHz)

    (* ASYNC_REG = "TRUE" *) reg [1:0] reg_ctrl_meta, reg_ctrl_sync;
    
    always @(posedge adapter_clk or negedge adapter_rst_n) begin
        if (!adapter_rst_n) begin
            reg_ctrl_meta <= 2'b00;
            reg_ctrl_sync <= 2'b00;
        end else begin
            reg_ctrl_meta <= reg_ctrl[1:0];
            reg_ctrl_sync <= reg_ctrl_meta;
        end
    end






    // Status Signal Sync (10 MHz -> 100 MHz)

    (* ASYNC_REG = "TRUE" *) reg [1:0] hw_status_meta, hw_status_sync;
    
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            hw_status_meta <= 2'b00;
            hw_status_sync <= 2'b00;
        end else begin
            hw_status_meta <= {hw_rdata_ready, hw_wdata_read_done};
            hw_status_sync <= hw_status_meta;
        end
    end




    // Safely capture y_out (10 MHz -> 100 MHz)  

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            top_out_data_sync <= 32'd0;
        end else if (hw_status_sync[1]) begin   // Bit 1 = Synchronized hw_rdata_ready
            top_out_data_sync <= top_out_data;
        end
    end





    // VHDL Core Instantiation

    adapter_top ffn_adapter_inst (
        .clk                      (adapter_clk),    
        .rst_n                    (adapter_rst_n),  
        
        .x_in                     (top_in_data),    
        .y_out                    (top_out_data),   
        
        .C_code_wdata_update_done (reg_ctrl_sync[0]),
        .C_code_rdata_read_done   (reg_ctrl_sync[1]),
        
        .wdata_read_done          (hw_wdata_read_done),
        .rdata_ready_from_hw      (hw_rdata_ready)
    );    

    // -------------------------------------------------------------
    // AXI Bus Logic 
    // -------------------------------------------------------------
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

            top_in_data   <= 32'd0;
            reg_ctrl      <= 32'd0;

            aw_holding    <= 1'b0;
            awaddr_hold   <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            w_holding     <= 1'b0;
            wdata_hold    <= 32'd0;
            wstrb_hold    <= 4'd0;
        end else begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_ARREADY <= 1'b0;

            // Accept AW independently
            if (!aw_holding && !S_AXI_BVALID && S_AXI_AWVALID) begin
                S_AXI_AWREADY <= 1'b1;
                aw_holding    <= 1'b1;
                awaddr_hold   <= S_AXI_AWADDR;
            end

            // Accept W independently
            if (!w_holding && !S_AXI_BVALID && S_AXI_WVALID) begin
                S_AXI_WREADY <= 1'b1;
                w_holding    <= 1'b1;
                wdata_hold   <= S_AXI_WDATA;
                wstrb_hold   <= S_AXI_WSTRB;
            end

            // Perform write when both AW and W are captured
            if (do_write) begin
                case (awaddr_hold[3:2])
                    2'b00: begin // top_in_data (0x00)
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (wstrb_hold[byte_index])
                                top_in_data[byte_index*8 +: 8] <= wdata_hold[byte_index*8 +: 8];
                        end
                    end
                    2'b01: begin // reg_ctrl (0x04)
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (wstrb_hold[byte_index])
                                reg_ctrl[byte_index*8 +: 8] <= wdata_hold[byte_index*8 +: 8];
                        end
                    end
                    2'b10: ; // read-only (Status)
                    2'b11: ; // read-only (y_out)
                endcase 

                aw_holding   <= 1'b0;
                w_holding    <= 1'b0;
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            // Read channel
            if (!S_AXI_RVALID && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b1;

                case (S_AXI_ARADDR[3:2])
                    2'b00: S_AXI_RDATA <= top_in_data;                   // 0x00
                    2'b01: S_AXI_RDATA <= reg_ctrl;                      // 0x04
                    2'b10: S_AXI_RDATA <= {30'd0, hw_status_sync};       // 0x08 
                    2'b11: S_AXI_RDATA <= top_out_data_sync;         // 0x0C (Safe read)
                endcase
                  
                S_AXI_RRESP  <= 2'b00;
                S_AXI_RVALID <= 1'b1;
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule




