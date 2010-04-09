/* This file is part of VoltDB.
 * Copyright (C) 2008-2010 VoltDB L.L.C.
 *
 * VoltDB is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * VoltDB is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with VoltDB.  If not, see <http://www.gnu.org/licenses/>.
 */

package org.voltdb.sysprocs;

import java.util.HashMap;
import java.util.List;

import org.voltdb.*;
import org.voltdb.ExecutionSite.SystemProcedureExecutionContext;
import org.voltdb.catalog.Cluster;
import org.voltdb.catalog.Database;
import org.voltdb.catalog.Procedure;
import org.voltdb.dtxn.DtxnConstants;

/**
 *
 *
 */
@ProcInfo(singlePartition = false)
public class AdHoc extends VoltSystemProcedure {

    Database m_db = null;

    final int AGG_DEPID = 1;
    final int COLLECT_DEPID = 2 | DtxnConstants.MULTIPARTITION_DEPENDENCY;

    @Override
    public void init(int numberOfPartitions, SiteProcedureConnection site,
            Procedure catProc, BackendTarget eeType, HsqlBackend hsql, Cluster cluster) {
        super.init(numberOfPartitions, site, catProc, eeType, hsql, cluster);
        site.registerPlanFragment(SysProcFragmentId.PF_runAdHocFragment, this);
        m_db = cluster.getDatabases().get("database");
    }

    @Override
    public DependencyPair executePlanFragment(HashMap<Integer, List<VoltTable>> dependencies, long fragmentId,
            ParameterSet params, SystemProcedureExecutionContext context) {

        // get the three params (depId, json plan, sql stmt)
        int outputDepId = (Integer) params.toArray()[0];
        String plan = (String) params.toArray()[1];
        String sql = (String) params.toArray()[2];
        int inputDepId = -1;

        // make dependency ids available to the execution engine
        if ((dependencies != null) && (dependencies.size() > 00)) {
            assert(dependencies.size() <= 1);
            for (int x : dependencies.keySet()) {
                inputDepId = x; break;
            }
            context.getExecutionEngine().stashWorkUnitDependencies(dependencies);
        }

        VoltTable table = null;

        if (VoltDB.getEEBackendType() == BackendTarget.HSQLDB_BACKEND) {
            // Call HSQLDB
            assert(sql != null);
            table = hsql.runDML(sql);
        }
        else
        {
            assert(plan != null);
            table =
                context.getExecutionEngine().
                executeCustomPlanFragment(plan, outputDepId, inputDepId, getTransactionId(),
                                          context.getLastCommittedTxnId(),
                                          context.getNextUndo());
        }

        return new DependencyPair(outputDepId, table);
    }

    public VoltTable[] run(SystemProcedureExecutionContext ctx,
            String aggregatorFragment, String collectorFragment,
            String sql, int isReplicatedTableDML) {

        boolean replicatedTableDML = isReplicatedTableDML == 1;

        SynthesizedPlanFragment[] pfs = null;
        VoltTable[] results = null;
        ParameterSet params = null;
        if (VoltDB.getEEBackendType() == BackendTarget.HSQLDB_BACKEND) {
            pfs = new SynthesizedPlanFragment[1];

            // JUST SEND ONE FRAGMENT TO HSQL, IT'LL IGNORE EVERYTHING BUT SQL AND DEPID
            pfs[0] = new SynthesizedPlanFragment();
            pfs[0].fragmentId = SysProcFragmentId.PF_runAdHocFragment;
            pfs[0].outputDepId = AGG_DEPID;
            pfs[0].multipartition = false;
            pfs[0].nonExecSites = false;
            params = new ParameterSet();
            params.setParameters(AGG_DEPID, "", sql);
            pfs[0].parameters = params;
        }
        else {
            pfs = new SynthesizedPlanFragment[2];

            if (collectorFragment != null) {
                pfs = new SynthesizedPlanFragment[2];

                // COLLECTION FRAGMENT NEEDS TO RUN FIRST
                pfs[1] = new SynthesizedPlanFragment();
                pfs[1].fragmentId = SysProcFragmentId.PF_runAdHocFragment;
                pfs[1].outputDepId = COLLECT_DEPID;
                pfs[1].multipartition = true;
                pfs[1].nonExecSites = false;
                params = new ParameterSet();
                params.setParameters(COLLECT_DEPID, collectorFragment, sql);
                pfs[1].parameters = params;
            }
            else {
                pfs = new SynthesizedPlanFragment[1];
            }

            // AGGREGATION FRAGMENT DEPENDS ON THE COLLECTION FRAGMENT
            pfs[0] = new SynthesizedPlanFragment();
            pfs[0].fragmentId = SysProcFragmentId.PF_runAdHocFragment;
            pfs[0].outputDepId = AGG_DEPID;
            if (collectorFragment != null)
                pfs[0].inputDepIds = new int[] { COLLECT_DEPID };
            pfs[0].multipartition = false;
            pfs[0].suppressDuplicates = true;
            pfs[0].nonExecSites = false;
            params = new ParameterSet();
            params.setParameters(AGG_DEPID, aggregatorFragment, sql);
            pfs[0].parameters = params;
        }

        // distribute and execute these fragments providing pfs and id of the
        // aggregator's output dependency table.
        results =
            executeSysProcPlanFragments(pfs, AGG_DEPID);

        // rather icky hack to handle how the number of modified tuples will always be
        // inflated when changing replicated tables - the user really dosn't want to know
        // the big number, just the small one
        if (replicatedTableDML) {
            assert(results.length == 1);
            long changedTuples = results[0].asScalarLong();
            assert((changedTuples % VoltDB.instance().getCatalogContext().numberOfPartitions) == 0);

            VoltTable retval = new VoltTable(new VoltTable.ColumnInfo("", VoltType.BIGINT));
            retval.addRow(changedTuples / VoltDB.instance().getCatalogContext().numberOfPartitions);
            results[0] = retval;
        }

        return results;
    }
}
