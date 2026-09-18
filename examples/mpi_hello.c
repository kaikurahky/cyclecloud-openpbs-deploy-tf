#include <mpi.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    int rank;
    int size;
    int name_length;
    char hostname[MPI_MAX_PROCESSOR_NAME];

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Get_processor_name(hostname, &name_length);
    printf("rank %d / %d on %s\n", rank, size, hostname);
    MPI_Finalize();
    return 0;
}