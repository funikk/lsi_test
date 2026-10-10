// vdrv_iso_and: PDK-independent clamp-to-0 isolation wrapper.
// In the commercial flow, replace with library isolation cells or let UPF
// insert them (see impl/commercial/cell_map.md).
module vdrv_iso_and #(
    parameter W = 1
)(
    input  wire         iso_en,
    input  wire [W-1:0] d,
    output wire [W-1:0] q
);
    assign q = d & {W{~iso_en}};
endmodule
