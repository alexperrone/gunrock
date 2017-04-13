// ----------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------

/**
 * @file
 * metis_partitioner.cuh
 *
 * @brief linkage to metis partitioner
 */

#pragma once

#ifdef METIS_FOUND
  #include <metis.h>
#endif

#include <gunrock/oprtr/1D_oprtr/for_each.cuh>
#include <gunrock/partitioner/partitioner_base.cuh>

namespace gunrock {
namespace partitioner {
namespace metis {

template <typename GraphT>
cudaError_t Partition(
    GraphT     &org_graph,
    GraphT*    &sub_graphs,
    util::Parameters &parameters,
    int         num_subgraphs = 1,
    PartitionFlag flag = PARTITION_NONE,
    util::Location target = util::HOST,
    float      *weitage = NULL)
{
    typedef typename GraphT::VertexT VertexT;
    typedef typename GraphT::SizeT   SizeT;
    typedef typename GraphT::ValueT  ValueT;
    typedef typename GraphT::CsrT    CsrT;
    typedef typename GraphT::GpT     GpT;

    cudaError_t retval = cudaSuccess;
    auto &partition_table = org_graph.GpT::partition_table;

#ifdef METIS_FOUND
{
    //typedef idxtype idx_t;
    idx_t       nodes  = org_graph.nodes;
    idx_t       edges  = org_graph.edges;
    idx_t       nsubgraphs  = num_subgraphs;
    idx_t       ncons  = 1;
    idx_t       objval;
    util::Array1D<SizeT, idx_t> tpartition_table;
    util::Array1D<SizeT, idx_t> trow_offsets;
    util::Array1D<SizeT, idx_t> tcolumn_indices;

    tpartition_table.SetName(
        "partitioner::metis::tpartition_table");
    retval = tpartition_table.Allocate(
        org_graph.nodes, target);
    if (retval) return retval;

    trow_offsets    .SetName(
        "partitioner::metis::trow_offsets");
    retval = trow_offsets     .Allocate(
        org_graph.nodes + 1, target);
    if (retval) return retval;

    tcolumn_indices .SetName(
        "partitioner::metis::tcolumn_indices");
    retval = tcolumn_indices  .Allocate(
        org_graph.edges, target);
    if (retval) return retval;

    retval = trow_offsets.ForEach(org_graph.CsrT::row_offsets,
        []__host__ __device__(idx_t &trow_offset, const SizeT &row_offset){
            trow_offset = row_offset;
        }, org_graph.nodes + 1, target);
    if (retval) return retval;

    retval = tcolumn_indices.ForEach(org_graph.CsrT::column_indices,
        []__host__ __device__(idx_t &tcolumn_index, const VertexT &column_index){
            tcolumn_index = column_index;
        }, org_graph.edges, target);
    if (retval) return retval;

    //int Status =
    METIS_PartGraphKway(
        &nodes,                      // nvtxs  : the number of vertices in the graph
        &ncons,                      // ncon   : the number of balancing constraints
        trow_offsets + 0,            // xadj   : the adjacency structure of the graph
        tcolumn_indices + 0,         // adjncy : the adjacency structure of the graph
        NULL,                        // vwgt   : the weights of the vertices
        NULL,                        // vsize  : the size of the vertices
        NULL,                        // adjwgt : the weights of the edges
        &nsubgraphs,                 // nparts : the number of parts to partition the graph
        NULL,                        // tpwgts : the desired weight for each partition and constraint
        NULL,                        // ubvec  : the allowed load imbalance tolerance 4 each constraint
        NULL,                        // options: the options
        &objval,                     // objval : the returned edge-cut or the total communication volume
        tpartition_table + 0);       // part   : the returned partition vector of the graph

    retval = partition_table.ForEach(tpartition_table,
        []__host__ __device__(int &partition, const idx_t &tpartition){
            partition = tpartition;
        }, org_graph.nodes, target);
    if (retval) return retval;

    if (retval = tpartition_table.Release()) return retval;
    if (retval = trow_offsets    .Release()) return retval;
    if (retval = tcolumn_indices .Release()) return retval;

}
#else
{

    retval = util::GRError(cudaErrorUnknown,
        "Metis was not found during installation, "
        "therefore metis partitioner cannot be used.",
        __FILE__, __LINE__);

} // METIS_FOUND
#endif

    return retval;
}

} //namespace metis
} //namespace partitioner
} //namespace gunrock

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
