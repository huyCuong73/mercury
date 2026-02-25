package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/x/precisebank"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestPreciseBankGenesis(t *testing.T) {
	s := precisebank.NewGenesisTestSuite(CreateEvmd)
	suite.Run(t, s)
}

func TestPreciseBankKeeper(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](CreateEvmd, "evm.IntegrationNetworkApp")
	s := precisebank.NewKeeperIntegrationTestSuite(create)
	suite.Run(t, s)
}
